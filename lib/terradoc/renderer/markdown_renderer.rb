# frozen_string_literal: true

require "set"

module Terradoc
  module Renderer
    class MarkdownRenderer
      def initialize(projects:, relationships:, config:, title: nil)
        @projects = Array(projects)
        @relationships = Array(relationships)
        @config = config
        @title = title
        @mermaid = MermaidDiagram.new
      end

      def render
        sections = []
        sections << render_header
        sections << render_overview
        sections << render_cross_product_dependencies if render_section?(:network)
        @projects.each do |project|
          sections << render_project(project)
        end
        sections << render_appendix
        sections.compact.join("\n\n---\n\n")
      end

      private

      def render_header
        [
          "# Infrastructure Design Document — #{document_title}",
          "",
          "Generated at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
          "Target directory: #{@projects.map(&:path).join(', ')}",
          "Terraform file count: #{@projects.sum { |project| project.parsed_files.size }}"
        ].join("\n")
      end

      def render_overview
        total_resources = @projects.sum { |project| project.resources.size }
        services = @projects.flat_map { |project| project.resources.map(&:type) }.uniq.sort
        [
          "## Overview",
          "",
          "- Total resources: #{total_resources}",
          "- Products: #{@projects.size}",
          "- Product list: #{@projects.map(&:name).join(', ')}",
          "- GCP services in use: #{services.join(', ')}"
        ].join("\n")
      end

      def render_cross_product_dependencies
        [
          "## Cross-Product Dependencies",
          "",
          @mermaid.render_project_relationships(projects: @projects, relationships: @relationships)
        ].join("\n")
      end

      def render_project(project)
        sections = ["## #{project.name}"]

        if project.shared?
          sections << "### Consumer Products"
          sections << render_shared_project_consumers(project)
        end

        if render_section?(:resources)
          sections << "### Resources"
          sections << ResourceTable.new(resources: project.resources).render
        end

        if render_section?(:network)
          sections << "### Network Configuration"
          sections << @mermaid.render_network(project.network, project_name: project.name)
        end

        if render_section?(:security)
          sections << "### Security Settings"
          sections << SecuritySection.new(report: project.security_report).render
        end

        if render_section?(:cost)
          sections << "### Cost Estimation"
          sections << CostSection.new(items: project.cost_items).render
        end

        sections.join("\n\n")
      end

      def render_appendix
        parts = ["## Appendix"]
        parts << ""
        parts << "### All Variables"
        variable_lines = @projects.flat_map do |project|
          project.variables.map do |entry|
            "- #{project.name}: `#{entry.block.labels.first}`"
          end
        end
        parts << (variable_lines.empty? ? "None" : variable_lines.join("\n"))
        parts << ""
        parts << "### All Outputs"
        output_lines = @projects.flat_map do |project|
          project.outputs.map do |entry|
            "- #{project.name}: `#{entry.block.labels.first}`"
          end
        end
        parts << (output_lines.empty? ? "None" : output_lines.join("\n"))
        parts << ""
        parts << "### Unresolved References"
        parts << render_unresolved_references
        parts.join("\n")
      end

      def render_section?(section)
        sections = Array(@config.sections).map(&:to_s)
        sections.include?("all") || sections.include?(section.to_s)
      end

      def render_unresolved_references
        known_identifiers = @projects.flat_map(&:all_resource_like).map(&:identifier).to_set

        unresolved = @projects.flat_map do |project|
          project.resources.flat_map do |resource|
            resource.references.filter_map do |ref|
              identifier = unresolved_reference_identifier(ref)
              next if identifier.nil?
              next if known_identifiers.include?(identifier)

              "- #{project.name}: `#{resource.identifier}` -> `#{ref}`"
            end
          end
        end.uniq

        unresolved.empty? ? "None" : unresolved.join("\n")
      end

      def unresolved_reference_identifier(ref)
        return nil if ref.nil? || ref.empty?
        return nil if ref.start_with?("var.", "local.", "module.", "data.", "path.")

        parts = ref.split(".")
        return nil if parts.length < 2

        parts[0, 2].join(".")
      end

      def render_shared_project_consumers(project)
        consumers = @relationships.filter_map do |relationship|
          target_project = relationship_target_project(relationship)
          next unless target_project == project

          source_project = relationship_source_project(relationship)
          next if source_project.nil? || source_project == project

          source_project.name
        end.uniq.sort

        consumers.empty? ? "None" : consumers.map { |name| "- #{name}" }.join("\n")
      end

      def relationship_target_project(relationship)
        if relationship.target.is_a?(Terradoc::Model::Project)
          relationship.target
        elsif relationship.target.respond_to?(:project)
          relationship.target.project
        end
      end

      def relationship_source_project(relationship)
        if relationship.source.is_a?(Terradoc::Model::Project)
          relationship.source
        elsif relationship.source.respond_to?(:project)
          relationship.source.project
        end
      end

      def document_title
        @title || "terradoc"
      end
    end
  end
end
