# frozen_string_literal: true

module Docsterra
  module Model
    class Resource
      attr_reader :type, :name, :attributes, :project, :references, :meta, :source_file,
                  :comment, :kind, :display_name, :category, :key_attributes

      def initialize(
        type:,
        name:,
        attributes:,
        project:,
        references: [],
        meta: {},
        source_file: nil,
        comment: nil,
        kind: :resource,
        display_name: nil,
        category: :other,
        key_attributes: []
      )
        @type = type
        @name = name
        @attributes = attributes || {}
        @project = project
        @references = Array(references).uniq
        @meta = meta || {}
        @source_file = source_file
        @comment = comment
        @kind = kind
        @display_name = display_name || type
        @category = category || :other
        @key_attributes = Array(key_attributes)
      end

      def identifier
        "#{type}.#{name}"
      end

      def data_source?
        kind == :data
      end

      def resource?
        kind == :resource
      end

      def description
        attribute_text("description") || comment
      end

      def attribute(path)
        segments = path.to_s.split(".")
        traverse(@attributes, segments)
      end

      def attribute_text(path)
        value = attribute(path)
        return nil if value.nil?

        case value
        when Array
          value.map { |item| item.is_a?(Hash) ? compact_hash(item) : Docsterra::Parser::ExpressionInspector.to_text(item) }
               .map(&:to_s)
               .join(", ")
        when Hash
          compact_hash(value).inspect
        else
          Docsterra::Parser::ExpressionInspector.to_text(value)
        end
      end

      def attribute_ruby(path)
        value = attribute(path)
        return nil if value.nil?
        return value.map { |item| item.is_a?(Hash) ? hash_to_ruby(item) : Docsterra::Parser::ExpressionInspector.to_ruby(item) } if value.is_a?(Array)
        return hash_to_ruby(value) if value.is_a?(Hash)

        Docsterra::Parser::ExpressionInspector.to_ruby(value)
      end

      private

      def traverse(value, segments)
        return value if segments.empty?

        head = segments.first
        tail = segments.drop(1)

        case value
        when Hash
          traverse(value[head], tail)
        when Array
          next_value = if integer_string?(head)
                         value[head.to_i]
                       else
                         value.first
                       end
          traverse(next_value, integer_string?(head) ? tail : segments)
        end
      end

      def integer_string?(value)
        value.match?(/\A\d+\z/)
      end

      def compact_hash(hash)
        hash.transform_values do |value|
          if value.is_a?(Hash)
            compact_hash(value)
          elsif value.is_a?(Array)
            value.map { |entry| entry.is_a?(Hash) ? compact_hash(entry) : Docsterra::Parser::ExpressionInspector.to_text(entry) }
          else
            Docsterra::Parser::ExpressionInspector.to_text(value)
          end
        end
      end

      def hash_to_ruby(hash)
        hash.transform_values do |value|
          if value.is_a?(Hash)
            hash_to_ruby(value)
          elsif value.is_a?(Array)
            value.map { |entry| entry.is_a?(Hash) ? hash_to_ruby(entry) : Docsterra::Parser::ExpressionInspector.to_ruby(entry) }
          else
            Docsterra::Parser::ExpressionInspector.to_ruby(value)
          end
        end
      end
    end
  end
end
