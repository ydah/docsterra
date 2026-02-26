# frozen_string_literal: true

module Terradoc
  module Analyzer
    class CostAnalyzer
      CostItem = Struct.new(:resource_name, :resource_type, :spec, :region, :note, :resource, keyword_init: true)

      def analyze(resources)
        resources.filter_map do |resource|
          build_cost_item(resource)
        end
      end

      private

      def build_cost_item(resource)
        case resource.type
        when "google_compute_instance"
          CostItem.new(
            resource_name: resource.attribute_text("name") || resource.name,
            resource_type: resource.type,
            spec: resource.attribute_text("machine_type"),
            region: resource.attribute_text("zone"),
            note: nil,
            resource: resource
          )
        when "google_container_cluster"
          node_type = resource.attribute_text("node_config.machine_type")
          node_count = resource.attribute_text("initial_node_count")
          CostItem.new(
            resource_name: resource.attribute_text("name") || resource.name,
            resource_type: resource.type,
            spec: [node_type, node_count && "x #{node_count}"].compact.join(" "),
            region: resource.attribute_text("location"),
            note: "Autopilot: #{truthy_string(resource.attribute_ruby('enable_autopilot'))}",
            resource: resource
          )
        when "google_container_node_pool"
          CostItem.new(
            resource_name: resource.attribute_text("name") || resource.name,
            resource_type: resource.type,
            spec: resource.attribute_text("node_config.machine_type"),
            region: resource.attribute_text("location") || resource.attribute_text("region"),
            note: node_pool_note(resource),
            resource: resource
          )
        when "google_sql_database_instance"
          CostItem.new(
            resource_name: resource.attribute_text("name") || resource.name,
            resource_type: resource.type,
            spec: resource.attribute_text("settings.tier") || resource.attribute_text("tier"),
            region: resource.attribute_text("region"),
            note: "HA: #{truthy_string((resource.attribute_text('settings.availability_type') || resource.attribute_text('availability_type')).to_s == 'REGIONAL')}",
            resource: resource
          )
        when "google_storage_bucket"
          CostItem.new(
            resource_name: resource.attribute_text("name") || resource.name,
            resource_type: resource.type,
            spec: nil,
            region: resource.attribute_text("location"),
            note: "class: #{resource.attribute_text('storage_class')}",
            resource: resource
          )
        when "google_redis_instance"
          CostItem.new(
            resource_name: resource.attribute_text("name") || resource.name,
            resource_type: resource.type,
            spec: "memory_size_gb=#{resource.attribute_text('memory_size_gb')}",
            region: resource.attribute_text("region"),
            note: "tier: #{resource.attribute_text('tier')}",
            resource: resource
          )
        when "google_compute_disk"
          CostItem.new(
            resource_name: resource.attribute_text("name") || resource.name,
            resource_type: resource.type,
            spec: "#{resource.attribute_text('size')}GB #{resource.attribute_text('type')}".strip,
            region: resource.attribute_text("zone"),
            note: nil,
            resource: resource
          )
        else
          nil
        end
      end

      def truthy_string(value)
        case value
        when true then "yes"
        when false then "no"
        else
          value.nil? ? "unknown" : value.to_s
        end
      end

      def node_pool_note(resource)
        min = resource.attribute_text("autoscaling.min_node_count")
        max = resource.attribute_text("autoscaling.max_node_count")
        return nil if min.nil? && max.nil?

        "autoscaling: #{min || '?'}-#{max || '?'}"
      end
    end
  end
end
