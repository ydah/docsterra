# frozen_string_literal: true

module Terradoc
  module Analyzer
    class DependencyAnalyzer
      def analyze(projects)
        relationships = []
        resource_index = build_resource_index(projects)
        name_index = build_name_index(projects)
        service_account_index = build_service_account_index(projects)

        projects.each do |project|
          relationships.concat(detect_reference_relationships(project, resource_index))
          relationships.concat(detect_data_source_relationships(project, name_index))
          relationships.concat(detect_service_account_relationships(project, service_account_index))
        end

        deduplicate(relationships)
      end

      private

      def build_resource_index(projects)
        projects.each_with_object({}) do |project, index|
          project.resources.each { |resource| index[resource.identifier] = resource }
        end
      end

      def build_name_index(projects)
        projects.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |project, index|
          project.resources.each do |resource|
            key = [resource.type, resource.attribute_text("name") || resource.attribute_text("dataset_id") || resource.name]
            index[key] << resource
          end
        end
      end

      def build_service_account_index(projects)
        projects.each_with_object({}) do |project, index|
          project.resources.select { |resource| resource.type == "google_service_account" }.each do |sa|
            account_id = sa.attribute_text("account_id")
            email = sa.attribute_text("email")
            [account_id, email].compact.each { |key| index[key] = sa }
          end
        end
      end

      def detect_reference_relationships(project, resource_index)
        project.resources.flat_map do |resource|
          resource.references.filter_map do |ref|
            target = resource_index[reference_identifier(ref)]
            next unless target
            next if target.project == project

            rel_type = target.project.shared? ? :shared_resource : relation_type_for_target(target)
            Model::Relationship.new(
              source: resource,
              target: target,
              type: rel_type,
              detail: "Reference #{ref}"
            )
          end
        end
      end

      def detect_data_source_relationships(project, name_index)
        project.data_sources.filter_map do |data_source|
          lookup_key = [data_source.type, data_source.attribute_text("name") || data_source.attribute_text("dataset_id")]
          matches = name_index[lookup_key].reject { |resource| resource.project == project }
          next if matches.empty?

          target = matches.first
          rel_type = target.project.shared? ? :shared_resource : relation_type_for_target(target)
          Model::Relationship.new(
            source: project,
            target: target.project,
            type: rel_type,
            detail: "Data source #{data_source.type}.#{data_source.name} uses #{lookup_key[1]}"
          )
        end.compact
      end

      def detect_service_account_relationships(project, service_account_index)
        project.resources.filter { |resource| resource.type.match?(/_iam_(member|binding)\z/) }.filter_map do |resource|
          members = Array(resource.attribute_ruby("members")) + [resource.attribute_text("member")]
          target_sa = members.compact.lazy.map { |member| find_service_account_in_member(member.to_s, service_account_index) }.find(&:itself)
          next unless target_sa
          next if target_sa.project == project

          Model::Relationship.new(
            source: resource,
            target: target_sa,
            type: :iam,
            detail: "IAM member uses service account from #{target_sa.project.name}"
          )
        end
      end

      def find_service_account_in_member(member, service_account_index)
        service_account_index.each do |key, resource|
          return resource if key && member.include?(key)
        end
        nil
      end

      def reference_identifier(ref)
        return nil unless ref

        parts = ref.split(".")
        return nil if parts.length < 2

        parts[0, 2].join(".")
      end

      def relation_type_for_target(target)
        target.category == :networking ? :network : :reference
      end

      def deduplicate(relationships)
        relationships.each_with_object([]) do |relationship, unique|
          unique << relationship unless unique.any? { |existing| existing.key == relationship.key }
        end
      end
    end
  end
end
