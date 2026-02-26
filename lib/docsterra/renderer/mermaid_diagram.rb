# frozen_string_literal: true

module Docsterra
  module Renderer
    class MermaidDiagram
      MAX_ENDPOINTS = 20

      def render_network(network, project_name: nil)
        return mermaid_block("graph TB\n  empty[\"No network resources\"]") if network.nil? || network.empty?

        lines = ["graph TB"]
        vpc_ids = {}

        network.vpcs.each do |vpc|
          vpc_id = node_id("vpc_#{vpc.name}")
          vpc_ids[vpc.identifier] = vpc_id
          vpc_label = vpc.attribute_text("name") || vpc.name
          lines << "  subgraph #{vpc_id}[\"#{escape(vpc_label)}\"]"

          subnets = network.subnets.select { |subnet| linked_to?(network.links, subnet, vpc) }
          subnets.each do |subnet|
            subnet_id = node_id("subnet_#{subnet.name}")
            subnet_label = "#{subnet.attribute_text('name') || subnet.name} (#{subnet.attribute_text('ip_cidr_range')})"
            lines << "    subgraph #{subnet_id}[\"#{escape(subnet_label)}\"]"
            lines << "    end"
          end
          lines << "  end"
        end

        endpoints = network.endpoints.first(MAX_ENDPOINTS)
        endpoints.each do |endpoint|
          eid = node_id("ep_#{endpoint.identifier}")
          lines << "  #{eid}[\"#{escape(endpoint_label(endpoint))}\"]"
        end

        network.load_balancers.each do |lb|
          lid = node_id("lb_#{lb.identifier}")
          lines << "  #{lid}[\"#{escape(endpoint_label(lb))}\"]"
        end

        network.links.each do |link|
          sid = node_id("ep_#{link[:source].identifier}")
          tid = vpc_ids[link[:target].identifier] || node_id("ep_#{link[:target].identifier}")
          lines << "  #{sid} --> #{tid}"
        end

        network.firewall_rules.each do |fw|
          ref = network.links.find { |link| link[:source] == fw }
          next unless ref

          source_id = node_id("ep_#{fw.identifier}")
          target_id = vpc_ids[ref[:target].identifier]
          lines << "  #{source_id} -. #{escape(fw.attribute_text('name') || fw.name)} .-> #{target_id}" if target_id
        end

        mermaid_block(lines.join("\n"))
      end

      def render_project_relationships(projects:, relationships:)
        return mermaid_block("graph LR\n  empty[\"No cross-product dependencies\"]") if relationships.nil? || relationships.empty?

        lines = ["graph LR"]
        Array(projects).each do |project|
          pid = node_id("project_#{project.name}")
          lines << "  subgraph #{pid}[\"#{escape(project.name)}\"]"
          representatives_for(project).each do |resource|
            rid = node_id(resource_node_key(project, resource))
            lines << "    #{rid}[\"#{escape(endpoint_label(resource))}\"]"
          end
          lines << "  end"
        end

        Array(relationships).each_with_index do |relationship, index|
          source_id = relationship_node_id(relationship.source, index)
          target_id = relationship_node_id(relationship.target, index)
          label = escape(relationship.detail.to_s)
          lines << "  #{source_id} #{edge_expression(relationship.type, label)} #{target_id}"
        end

        mermaid_block(lines.join("\n"))
      end

      private

      def linked_to?(links, source, target)
        links.any? { |link| link[:source] == source && link[:target] == target }
      end

      def representatives_for(project)
        project.resources
               .sort_by(&:identifier)
               .select { |resource| %i[compute networking database storage messaging analytics iam].include?(resource.category) }
               .first(5)
      end

      def relationship_node_id(object, fallback_index)
        if object.is_a?(Docsterra::Model::Resource)
          node_id(resource_node_key(object.project, object))
        elsif object.is_a?(Docsterra::Model::Project)
          node_id("project_#{object.name}")
        else
          node_id("rel_#{fallback_index}_#{object}")
        end
      end

      def resource_node_key(project, resource)
        "#{project.name}_#{resource.identifier}"
      end

      def endpoint_label(resource)
        short_type = resource.type.to_s.sub(/\Agoogle_/, "")
        "#{resource.name}\\n#{short_type}"
      end

      def edge_expression(type, label)
        case type
        when :network
          "==>|#{label}|"
        when :iam
          "-. #{label} .->"
        when :shared_resource
          "-- #{label} -->"
        else
          "-->|#{label}|"
        end
      end

      def node_id(text)
        text.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
      end

      def escape(text)
        text.to_s.gsub('"', '\"')
      end

      def mermaid_block(body)
        "```mermaid\n#{body}\n```"
      end
    end
  end
end
