# frozen_string_literal: true

require_relative "terradoc/version"
require_relative "terradoc/config"
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
    # @return [String]
    def generate(*paths, **options)
      config = Config.from_cli_options(paths: paths, options: options)
      render_placeholder_markdown(config)
    end

    # Load configuration and generate a Markdown document.
    #
    # @param path [String] config file path
    # @return [String]
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
      {
        paths: config.paths,
        output_path: config.output_path,
        sections: config.sections,
        ignore_patterns: config.ignore_patterns
      }
    end

    private

    def render_placeholder_markdown(config)
      lines = [
        "# Infrastructure Design Document",
        "",
        "Generated at: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}",
        "Paths: #{config.paths.empty? ? '(none)' : config.paths.join(', ')}",
        "Sections: #{config.sections.join(', ')}",
        "",
        "> Placeholder output. Parser/analyzers/renderers will be implemented in later phases."
      ]
      lines.join("\n")
    end
  end
end
