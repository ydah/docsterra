# frozen_string_literal: true

require "yaml"
require "pathname"

module Terradoc
  class Config
    DEFAULT_CONFIG_PATH = ".terradoc.yml"
    DEFAULT_OUTPUT_PATH = "./infrastructure.md"
    DEFAULT_SECTIONS = ["all"].freeze

    attr_reader :config_path, :paths, :products, :output_path, :output,
                :sections, :resource_attributes, :ignore_patterns, :verbose

    def self.load(path = DEFAULT_CONFIG_PATH)
      raw = File.exist?(path) ? parse_yaml(path) : {}
      build_from_hash(raw, path: path)
    end

    def self.from_cli_options(paths:, options:)
      normalized = normalize_options(options)
      config_path = normalized.fetch(:config, DEFAULT_CONFIG_PATH)
      base = load(config_path)
      base.merge_cli(paths: paths, options: normalized, config_path: config_path)
    end

    def initialize(
      config_path: DEFAULT_CONFIG_PATH,
      paths: [],
      products: [],
      output_path: DEFAULT_OUTPUT_PATH,
      sections: DEFAULT_SECTIONS,
      resource_attributes: {},
      ignore_patterns: [],
      verbose: false
    )
      @config_path = config_path
      @products = products
      @paths = normalize_paths(paths, products)
      @output_path = output_path
      @sections = normalize_sections(sections)
      @resource_attributes = resource_attributes || {}
      @ignore_patterns = Array(ignore_patterns).compact
      @verbose = !verbose.nil?
      @output = { "path" => @output_path, "sections" => @sections.dup }
    end

    def merge_cli(paths:, options:, config_path:)
      self.class.new(
        config_path: config_path,
        paths: paths.empty? ? @paths : paths,
        products: @products,
        output_path: options.fetch(:output, @output_path),
        sections: options.key?(:sections) ? options[:sections] : @sections,
        resource_attributes: @resource_attributes,
        ignore_patterns: @ignore_patterns + Array(options[:ignore]),
        verbose: options.fetch(:verbose, @verbose)
      )
    end

    def product_definitions
      if products.any?
        products.map do |product|
          hash = product.transform_keys(&:to_s)
          {
            "name" => hash["name"] || File.basename(hash.fetch("path")),
            "path" => resolve_config_path(hash.fetch("path")),
            "shared" => !hash["shared"].nil?
          }
        end
      else
        paths.map do |path|
          {
            "name" => File.basename(path.to_s),
            "path" => path.to_s,
            "shared" => false
          }
        end
      end
    end

    private

    def normalize_paths(paths, products)
      explicit_paths = Array(paths).compact.map(&:to_s)
      return explicit_paths unless explicit_paths.empty?

      Array(products).filter_map { |product| product["path"] || product[:path] }
    end

    def normalize_sections(sections)
      return DEFAULT_SECTIONS if sections.nil?
      return sections if sections.is_a?(Array)

      sections.to_s.split(",").map(&:strip).reject(&:empty?).yield_self do |list|
        list.empty? ? DEFAULT_SECTIONS : list
      end
    end

    def resolve_config_path(path)
      return path if path.nil?
      return path if Pathname.new(path).absolute?

      base_dir = File.dirname(config_path || DEFAULT_CONFIG_PATH)
      return path if base_dir.nil? || base_dir == "."

      File.expand_path(path, base_dir)
    end

    class << self
      private

      def parse_yaml(path)
        YAML.safe_load(File.read(path), aliases: true) || {}
      rescue Psych::SyntaxError => e
        raise Terradoc::Error, "Invalid config file #{path}: #{e.message}"
      end

      def build_from_hash(raw, path:)
        output = raw.fetch("output", {})
        new(
          config_path: path,
          products: Array(raw["products"]),
          output_path: output.fetch("path", DEFAULT_OUTPUT_PATH),
          sections: output.fetch("sections", DEFAULT_SECTIONS),
          resource_attributes: raw.fetch("resource_attributes", {}),
          ignore_patterns: raw.fetch("ignore", []),
          verbose: false
        )
      end

      def normalize_options(options)
        return {} if options.nil?

        options.to_h.transform_keys(&:to_sym)
      end
    end
  end
end
