# frozen_string_literal: true

require "fileutils"

module Terradoc
  class Document
    attr_reader :projects, :relationships, :config, :warnings

    def initialize(projects:, relationships:, config:, warnings:, markdown:)
      @projects = Array(projects)
      @relationships = Array(relationships)
      @config = config
      @warnings = Array(warnings)
      @markdown = markdown
    end

    def to_markdown
      @markdown
    end

    def save(path = config.output_path)
      directory = File.dirname(path)
      FileUtils.mkdir_p(directory) unless directory == "." || Dir.exist?(directory)
      File.write(path, @markdown)
      path
    end

    def summary
      {
        project_count: projects.size,
        resource_count: projects.sum { |project| project.resources.size },
        data_source_count: projects.sum { |project| project.data_sources.size },
        warning_count: warnings.size
      }
    end
  end
end
