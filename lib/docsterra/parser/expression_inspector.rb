# frozen_string_literal: true

module Docsterra
  module Parser
    module ExpressionInspector
      module_function

      def to_text(node)
        case node
        when nil
          nil
        when AST::Literal
          format_literal(node.value)
        when AST::Reference
          node.parts.map { |part| part.is_a?(String) ? part : to_text(part) }.join(".")
        when AST::TemplateExpr
          node.parts.join
        when AST::RawExpr
          node.text
        when AST::ListExpr
          "[" + node.elements.map { |element| to_text(element) }.join(", ") + "]"
        when AST::MapExpr
          "{" + node.pairs.map { |k, v| "#{k} = #{to_text(v)}" }.join(", ") + "}"
        when AST::FunctionCall
          "#{node.name}(#{node.args.map { |arg| to_text(arg) }.join(', ')})"
        when AST::IndexExpr
          "#{to_text(node.expr)}[#{to_text(node.index)}]"
        when AST::ConditionalExpr
          "#{to_text(node.cond)} ? #{to_text(node.true_val)} : #{to_text(node.false_val)}"
        when AST::UnaryExpr
          "#{node.op}#{to_text(node.expr)}"
        when AST::BinaryExpr
          "#{to_text(node.left)} #{node.op} #{to_text(node.right)}"
        when AST::SplatExpr
          [to_text(node.expr), "*", node.attr].compact.join(".").gsub(".*.", ".*.")
        when AST::ForExpr
          render_for_expr(node)
        else
          node.to_s
        end
      end

      def to_ruby(node)
        case node
        when nil
          nil
        when AST::Literal
          node.value
        when AST::ListExpr
          node.elements.map { |element| to_ruby(element) }
        when AST::MapExpr
          node.pairs.transform_values { |value| to_ruby(value) }
        else
          to_text(node)
        end
      end

      def collect_references(node)
        refs = []
        walk(node) do |value|
          refs << to_text(value) if value.is_a?(AST::Reference)
        end
        refs.uniq.compact
      end

      def walk(node, &block)
        return if node.nil?

        yield node

        case node
        when AST::ListExpr
          node.elements.each { |element| walk(element, &block) }
        when AST::MapExpr
          node.pairs.each_value { |value| walk(value, &block) }
        when AST::FunctionCall
          node.args.each { |arg| walk(arg, &block) }
        when AST::IndexExpr
          walk(node.expr, &block)
          walk(node.index, &block)
        when AST::ConditionalExpr
          walk(node.cond, &block)
          walk(node.true_val, &block)
          walk(node.false_val, &block)
        when AST::ForExpr
          walk(node.collection, &block)
          walk(node.body, &block)
          walk(node.cond, &block)
        when AST::UnaryExpr
          walk(node.expr, &block)
        when AST::BinaryExpr
          walk(node.left, &block)
          walk(node.right, &block)
        when AST::SplatExpr
          walk(node.expr, &block)
        end
      end

      def render_for_expr(node)
        vars = [node.key_var, node.val_var].compact.join(", ")
        text = "for #{vars} in #{to_text(node.collection)} : #{to_text(node.body)}"
        text += " if #{to_text(node.cond)}" if node.cond
        wrapper_left = node.is_map ? "{" : "["
        wrapper_right = node.is_map ? "}" : "]"
        "#{wrapper_left}#{text}#{wrapper_right}"
      end
      private_class_method :render_for_expr

      def format_literal(value)
        case value
        when String
          value
        when NilClass
          "null"
        else
          value.to_s
        end
      end
      private_class_method :format_literal
    end
  end
end
