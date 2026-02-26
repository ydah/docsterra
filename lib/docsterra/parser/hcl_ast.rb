# frozen_string_literal: true

module Docsterra
  module Parser
    module AST
      def self.node(*members)
        Struct.new(*members, keyword_init: true)
      end

      # File-level AST nodes
      File = node(:blocks, :comments)
      Block = node(:type, :labels, :body, :comment)
      Attribute = node(:key, :value, :comment)

      # Value / expression nodes
      Literal = node(:value)
      ListExpr = node(:elements)
      MapExpr = node(:pairs)
      Reference = node(:parts)
      FunctionCall = node(:name, :args)
      TemplateExpr = node(:parts)
      IndexExpr = node(:expr, :index)
      ConditionalExpr = node(:cond, :true_val, :false_val)
      ForExpr = node(:key_var, :val_var, :collection, :body, :cond, :is_map)
      UnaryExpr = node(:op, :expr)
      BinaryExpr = node(:left, :op, :right)
      SplatExpr = node(:expr, :attr)
      RawExpr = node(:text)
    end
  end
end
