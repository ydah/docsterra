# frozen_string_literal: true

require "fileutils"
require "thor"

module Terradoc
  class CLI < Thor
    class_option :output,
                 type: :string,
                 aliases: "-o",
                 default: Config::DEFAULT_OUTPUT_PATH,
                 desc: "Output file path"
    class_option :config,
                 type: :string,
                 aliases: "-c",
                 default: Config::DEFAULT_CONFIG_PATH,
                 desc: "Config file path"
    class_option :sections,
                 type: :string,
                 aliases: "-s",
                 default: "all",
                 desc: "Comma-separated sections to generate"
    class_option :format,
                 type: :string,
                 aliases: "-f",
                 default: Config::DEFAULT_FORMAT,
                 desc: "Output format (currently: markdown)"
    class_option :verbose,
                 type: :boolean,
                 aliases: "-v",
                 default: false,
                 desc: "Enable verbose logging"
    class_option :ignore,
                 type: :array,
                 default: [],
                 desc: "Ignore directory patterns"

    desc "generate [PATHS...]", "Generate infrastructure document"
    def generate(*paths)
      document = Terradoc.generate(*paths, **runtime_options)
      document.save(options[:output])
      summary = document.summary
      say("Generated #{options[:output]} (#{summary[:resource_count]} resources across #{summary[:project_count]} projects)")
      Array(document.warnings).each { |warning| say("Warning: #{warning}") } if options[:verbose]
    rescue Terradoc::Error => e
      raise Thor::Error, e.message
    end

    desc "check [PATHS...]", "Dry-run parsing and print summary"
    def check(*paths)
      summary = Terradoc.check(*paths, **runtime_options)
      say("Terradoc check summary")
      say("Paths: #{summary[:paths].empty? ? '(none)' : summary[:paths].join(', ')}")
      say("Sections: #{summary[:sections].join(', ')}")
      say("Format: #{summary[:format]}")
      say("Output: #{summary[:output_path]}")
      say("Ignore: #{summary[:ignore_patterns].empty? ? '(none)' : summary[:ignore_patterns].join(', ')}")
      say("Projects: #{summary[:project_count]}")
      say("Resources: #{summary[:resource_count]}")
      say("Data Sources: #{summary[:data_source_count]}")
      Array(summary[:parse_warnings]).each { |warning| say("Warning: #{warning}") }
    rescue Terradoc::Error => e
      raise Thor::Error, e.message
    end

    desc "version", "Print version"
    def version
      say(Terradoc::VERSION)
    end

    map ["--version"] => :version

    def self.exit_on_failure?
      true
    end

    private

    def runtime_options
      options.to_h.transform_keys(&:to_sym)
    end
  end
end
