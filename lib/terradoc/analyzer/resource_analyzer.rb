# frozen_string_literal: true

module Terradoc
  module Analyzer
    class ResourceAnalyzer
      def initialize(registry: Parser::ResourceRegistry.new)
        @registry = registry
      end

      def analyze(project)
        project.resources = build_resources(project.resource_blocks, project, kind: :resource)
        project.data_sources = build_resources(project.data_blocks, project, kind: :data)
        project.resources
      end

      private

      def build_resources(entries, project, kind:)
        entries.map do |entry|
          block = entry.block
          resource_type = block.labels[0]
          name = block.labels[1] || block.labels[0]
          attributes = build_attribute_tree(block.body)
          refs = collect_references_from_attributes(attributes)
          meta = extract_meta(attributes)

          Model::Resource.new(
            type: resource_type,
            name: name,
            attributes: attributes,
            project: project,
            references: refs + Array(meta[:depends_on]),
            meta: meta,
            source_file: entry.file,
            comment: block.comment,
            kind: kind,
            display_name: @registry.display_name_for(resource_type),
            category: @registry.category_for(resource_type),
            key_attributes: @registry.key_attributes_for(resource_type)
          )
        end
      end

      def build_attribute_tree(items)
        tree = {}

        Array(items).each do |item|
          case item
          when Parser::AST::Attribute
            tree[item.key] = item.value
          when Parser::AST::Block
            block_hash = build_attribute_tree(item.body)
            block_hash["__labels"] = item.labels unless item.labels.nil? || item.labels.empty?
            tree[item.type] ||= []
            tree[item.type] << block_hash
          end
        end

        tree
      end

      def collect_references_from_attributes(value)
        case value
        when Hash
          value.values.flat_map { |child| collect_references_from_attributes(child) }.uniq
        when Array
          value.flat_map { |child| collect_references_from_attributes(child) }.uniq
        else
          Parser::ExpressionInspector.collect_references(value)
        end
      end

      def extract_meta(attributes)
        {
          count: attributes["count"],
          for_each: attributes["for_each"],
          depends_on: normalize_depends_on(attributes["depends_on"])
        }.compact
      end

      def normalize_depends_on(node)
        return [] if node.nil?

        case node
        when Parser::AST::ListExpr
          node.elements.map { |element| Parser::ExpressionInspector.to_text(element) }.compact
        when Parser::AST::RawExpr
          [node.text]
        else
          [Parser::ExpressionInspector.to_text(node)]
        end
      end
    end
  end
end
