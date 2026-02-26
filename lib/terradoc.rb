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
      config = Config.from_cli_options(paths: paths, options: options)
      pipeline = build_pipeline(config)
      markdown = Renderer::MarkdownRenderer.new(
        projects: pipeline[:projects],
        relationships: pipeline[:relationships],
        config: config
      ).render
      Document.new(
        projects: pipeline[:projects],
        relationships: pipeline[:relationships],
        config: config,
        warnings: pipeline[:warnings],
        markdown: markdown
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
      config = Config.from_cli_options(paths: paths, options: options)
      pipeline = build_pipeline(config)
      {
        paths: config.product_definitions.map { |item| item["path"] },
        output_path: config.output_path,
        sections: config.sections,
        ignore_patterns: config.ignore_patterns,
        project_count: pipeline[:projects].size,
        resource_count: pipeline[:projects].sum { |project| project.resources.size },
        data_source_count: pipeline[:projects].sum { |project| project.data_sources.size },
        parse_warnings: pipeline[:warnings]
      }
    end

    private

    def build_pipeline(config)
      parser = Parser::HclParser.new
      registry = Parser::ResourceRegistry.new(custom_attributes: config.resource_attributes)
      module_resolver = Parser::ModuleResolver.new(parser: parser)
      resource_analyzer = Analyzer::ResourceAnalyzer.new(registry: registry)
      network_analyzer = Analyzer::NetworkAnalyzer.new
      security_analyzer = Analyzer::SecurityAnalyzer.new
      cost_analyzer = Analyzer::CostAnalyzer.new
      dependency_analyzer = Analyzer::DependencyAnalyzer.new

      warnings = []
      projects = build_projects(config: config, parser: parser, module_resolver: module_resolver, warnings: warnings)

      projects.each do |project|
        resource_analyzer.analyze(project)
        project.network = network_analyzer.analyze(project.resources)
        project.security_report = security_analyzer.analyze(project.resources)
        project.cost_items = cost_analyzer.analyze(project.resources)
      end

      relationships = dependency_analyzer.analyze(projects)
      { projects: projects, relationships: relationships, warnings: warnings }
    end

    def build_projects(config:, parser:, module_resolver:, warnings:)
      config.product_definitions.map do |product|
        tf_files = find_tf_files(product["path"], config.ignore_patterns)
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

        resolve_local_modules!(project, module_resolver, warnings)
        project
      end
    end

    def resolve_local_modules!(project, module_resolver, warnings)
      project.modules.each do |entry|
        result = module_resolver.resolve(project_path: project.path, module_block: entry.block)
        next unless result[:type] == :local

        result[:parsed_files].each do |file, ast|
          if ast.is_a?(Hash) && ast[:error]
            warnings << "Failed to parse module file #{file}: #{ast[:error]}"
          else
            project.parsed_files[file] = ast
          end
        end
      end
      project.reindex!
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
