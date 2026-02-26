# frozen_string_literal: true

require_relative "terradoc/version"
require_relative "terradoc/config"
require_relative "terradoc/document"
require_relative "terradoc/parser/hcl_parser"
require_relative "terradoc/parser/hcl_lexer"
require_relative "terradoc/parser/hcl_ast"
require_relative "terradoc/parser/expression_inspector"
require_relative "terradoc/parser/resource_registry"
require_relative "terradoc/parser/module_resolver"
require_relative "terradoc/analyzer/resource_analyzer"
require_relative "terradoc/analyzer/network_analyzer"
require_relative "terradoc/analyzer/security_analyzer"
require_relative "terradoc/analyzer/dependency_analyzer"
require_relative "terradoc/analyzer/cost_analyzer"
require_relative "terradoc/model/project"
require_relative "terradoc/model/resource"
require_relative "terradoc/model/relationship"
require_relative "terradoc/model/network"
require_relative "terradoc/renderer/markdown_renderer"
require_relative "terradoc/renderer/resource_table"
require_relative "terradoc/renderer/mermaid_diagram"
require_relative "terradoc/renderer/security_section"
require_relative "terradoc/renderer/cost_section"
require_relative "terradoc/cli"

module Terradoc
  class Error < StandardError; end

  class << self
    # Generate a Markdown document from Terraform paths.
    #
    # @param paths [Array<String>] Terraform root paths
    # @param options [Hash] CLI-like options
    # @return [Terradoc::Document]
    def generate(*paths, **options)
      title = options[:name]
      progress = options[:progress]
      config = Config.from_cli_options(paths: paths, options: options)
      validate_format!(config)
      progress&.call("Building terradoc pipeline...")
      pipeline = build_pipeline(config, progress: progress)
      markdown = Renderer::MarkdownRenderer.new(
        projects: pipeline[:projects],
        relationships: pipeline[:relationships],
        config: config,
        title: title
      ).render
      Document.new(
        projects: pipeline[:projects],
        relationships: pipeline[:relationships],
        config: config,
        warnings: pipeline[:warnings],
        markdown: markdown,
        title: title
      )
    end

    # Load configuration and generate a Markdown document.
    #
    # @param path [String] config file path
    # @return [Terradoc::Document]
    def from_config(path = Config::DEFAULT_CONFIG_PATH)
      generate(config: path)
    end

    # Dry-run helper used by the CLI.
    #
    # @param paths [Array<String>] Terraform root paths
    # @param options [Hash] CLI-like options
    # @return [Hash]
    def check(*paths, **options)
      progress = options[:progress]
      config = Config.from_cli_options(paths: paths, options: options)
      validate_format!(config)
      progress&.call("Building terradoc pipeline...")
      pipeline = build_pipeline(config, progress: progress)
      {
        paths: config.product_definitions.map { |item| item["path"] },
        output_path: config.output_path,
        sections: config.sections,
        format: config.format,
        ignore_patterns: config.ignore_patterns,
        project_count: pipeline[:projects].size,
        resource_count: pipeline[:projects].sum { |project| project.resources.size },
        data_source_count: pipeline[:projects].sum { |project| project.data_sources.size },
        parse_warnings: pipeline[:warnings]
      }
    end

    private

    def build_pipeline(config, progress: nil)
      progress&.call("Initializing parsers and analyzers")
      parser = Parser::HclParser.new
      registry = Parser::ResourceRegistry.new(custom_attributes: config.resource_attributes)
      module_resolver = Parser::ModuleResolver.new(parser: parser)
      resource_analyzer = Analyzer::ResourceAnalyzer.new(registry: registry)
      network_analyzer = Analyzer::NetworkAnalyzer.new
      security_analyzer = Analyzer::SecurityAnalyzer.new
      cost_analyzer = Analyzer::CostAnalyzer.new
      dependency_analyzer = Analyzer::DependencyAnalyzer.new

      warnings = []
      projects = build_projects(
        config: config,
        parser: parser,
        module_resolver: module_resolver,
        warnings: warnings,
        progress: progress
      )

      projects.each do |project|
        progress&.call("Analyzing #{project.name} (#{project.parsed_files.size} files)")
        resource_analyzer.analyze(project)
        project.network = network_analyzer.analyze(project.resources)
        project.security_report = security_analyzer.analyze(project.resources)
        project.cost_items = cost_analyzer.analyze(project.resources)
      end

      relationships = dependency_analyzer.analyze(projects)
      { projects: projects, relationships: relationships, warnings: warnings }
    end

    def validate_format!(config)
      return if config.format == "markdown"

      raise Error, "Unsupported format: #{config.format} (only 'markdown' is supported)"
    end

    def build_projects(config:, parser:, module_resolver:, warnings:, progress: nil)
      config.product_definitions.map do |product|
        progress&.call("Scanning #{product['name']} at #{product['path']}")
        tf_files = find_tf_files(product["path"], config.ignore_patterns)
        progress&.call("Parsing #{product['name']} (#{tf_files.size} Terraform files)")
        parsed_files = tf_files.each_with_object({}) do |file, result|
          result[file] = parser.parse_file(file)
        rescue StandardError => e
          warnings << "Failed to parse #{file}: #{e.message}"
        end

        project = Model::Project.new(
          name: product["name"],
          path: product["path"],
          parsed_files: parsed_files,
          shared: product["shared"]
        )

        resolve_local_modules!(project, module_resolver, warnings, progress: progress)
        project
      end
    end

    def resolve_local_modules!(project, module_resolver, warnings, progress: nil)
      processed_module_entries = {}

      loop do
        new_files_added = false
        pending_entries = pending_module_entries(project, processed_module_entries)
        break if pending_entries.empty?

        pending_entries.each do |entry|
          processed_module_entries[[entry.file, entry.block.object_id]] = true
          result = module_resolver.resolve(
            project_path: project.path,
            module_block: entry.block,
            base_path: File.dirname(entry.file)
          )
          next unless result[:type] == :local

          progress&.call("Resolving local module #{result[:module_name] || '(unnamed)'} for #{project.name}")
          new_files_added |= merge_resolved_module_files!(project, result, warnings)
        end

        break unless new_files_added

        project.reindex!
      end
      project.reindex!
    end

    def pending_module_entries(project, processed_module_entries)
      project.modules.reject do |entry|
        processed_module_entries.key?([entry.file, entry.block.object_id])
      end
    end

    def merge_resolved_module_files!(project, result, warnings)
      added = false

      result[:parsed_files].each do |file, ast|
        if ast.is_a?(Hash) && ast[:error]
          warnings << "Failed to parse module file #{file}: #{ast[:error]}"
          next
        end

        next if project.parsed_files.key?(file)

        project.parsed_files[file] = ast
        added = true
      end

      added
    end

    def find_tf_files(root_path, ignore_patterns)
      return [] if root_path.nil?

      root = File.expand_path(root_path)
      return [] unless Dir.exist?(root)

      Dir.glob(File.join(root, "**", "*.tf")).sort.reject do |file|
        relative = file.sub(%r{\A#{Regexp.escape(root)}/?}, "")
        next true if relative.start_with?("modules/")

        ignored?(relative, ignore_patterns)
      end
    end

    def ignored?(relative_path, patterns)
      Array(patterns).any? do |pattern|
        File.fnmatch?(pattern, relative_path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
      end
    end
  end
end
