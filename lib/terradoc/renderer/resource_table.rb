# frozen_string_literal: true

module Terradoc
  module Renderer
    class ResourceTable
      CATEGORY_LABELS = {
        compute: "Compute",
        networking: "Networking",
        database: "Database",
        storage: "Storage",
        analytics: "Analytics",
        iam: "IAM",
        messaging: "Messaging",
        platform: "Platform",
        other: "Other"
      }.freeze

      def initialize(resources:)
        @resources = Array(resources).select(&:resource?)
      end

      def render
        return "No resources" if @resources.empty?

        grouped = @resources.group_by(&:category)
        sections = grouped.keys.sort_by { |category| CATEGORY_LABELS.fetch(category, category.to_s).downcase }.map do |category|
          render_group(category, grouped.fetch(category))
        end
        sections.join("\n\n")
      end

      private

      def render_group(category, resources)
        lines = []
        lines << "#### #{CATEGORY_LABELS.fetch(category, category.to_s.capitalize)}"
        lines << ""
        lines << "| Resource Type | Resource Name | Key Attributes | Description |"
        lines << "|---|---|---|---|"

        resources.sort_by(&:identifier).each do |resource|
          lines << "| `#{resource.type}` | `#{resource.name}` | #{format_key_attributes(resource)} | #{escape_cell(resource.description)} |"
        end
        lines.join("\n")
      end

      def format_key_attributes(resource)
        values = resource.key_attributes.filter_map do |path|
          value = resource.attribute_text(path)
          next if value.nil? || value.empty?

          "`#{path}`: `#{value}`"
        end

        escape_cell(values.empty? ? "—" : values.join("<br/>"))
      end

      def escape_cell(text)
        text.to_s.gsub("|", "\\|")
      end
    end
  end
end
