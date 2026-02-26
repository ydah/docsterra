# frozen_string_literal: true

module Terradoc
  module Parser
    class ModuleResolver
      LOCAL_PREFIXES = ["./", "../"].freeze

      def initialize(parser: HclParser.new)
        @parser = parser
        @cache = {}
      end

      def resolve(project_path:, module_block:)
        source_node = find_attribute(module_block, "source")
        source = source_node && literal_like_text(source_node)

        return unresolved_result(module_block, source) if source.nil?

        if local_source?(source)
          resolve_local_module(project_path, module_block, source)
        else
          unresolved_result(module_block, source, local: false, reason: "remote module source is not parsed")
        end
      end

      private

      def resolve_local_module(project_path, module_block, source)
        absolute_path = File.expand_path(source, project_path)

        cached = @cache[absolute_path]
        return cached if cached

        tf_files = Dir.glob(File.join(absolute_path, "**", "*.tf")).sort
        parsed_files = tf_files.each_with_object({}) do |file, result|
          result[file] = @parser.parse_file(file)
        rescue StandardError => e
          result[file] = { error: e.message }
        end

        @cache[absolute_path] = {
          type: :local,
          source: source,
          absolute_path: absolute_path,
          module_name: module_block.labels&.first,
          parsed_files: parsed_files
        }
      end

      def unresolved_result(module_block, source, local: nil, reason: "module source is not resolvable")
        {
          type: :unresolved,
          source: source,
          absolute_path: nil,
          module_name: module_block.labels&.first,
          parsed_files: {},
          local: local,
          reason: reason
        }
      end

      def local_source?(source)
        LOCAL_PREFIXES.any? { |prefix| source.start_with?(prefix) }
      end

      def find_attribute(block, key)
        return nil unless block.respond_to?(:body)

        block.body.find do |item|
          item.is_a?(AST::Attribute) && item.key == key
        end&.value
      end

      def literal_like_text(node)
        case node
        when AST::Literal
          node.value.is_a?(String) ? node.value : node.value.to_s
        when AST::TemplateExpr
          node.parts.join
        when AST::RawExpr
          node.text
        else
          nil
        end
      end
    end
  end
end
