# frozen_string_literal: true

module Terradoc
  module Parser
    class HclParser
      class ParseError < StandardError; end

      attr_reader :tokens

      def initialize(lexer: HclLexer.new)
        @lexer = lexer
      end

      def parse(text)
        @source = text
        @tokens = @lexer.tokenize(text)
        @index = 0

        blocks = []
        while !eof?
          leading_comment = consume_trivia
          break if eof?

          if block_start?
            blocks << parse_block(comment: leading_comment)
          else
            advance_token
          end
        end

        AST::File.new(
          blocks: blocks,
          comments: @tokens.select { |token| token.type == :COMMENT }.map(&:value)
        )
      end

      def parse_file(path)
        parse(::File.read(path))
      end

      private

      def parse_block(comment:)
        type = consume(:IDENT).value
        labels = []

        until check?(:LBRACE) || eof?
          if check?(:STRING) || check?(:IDENT) || check?(:NUMBER) || check?(:BOOL)
            labels << advance_token.value
            next
          end

          break if check?(:NEWLINE)

          if check?(:COMMENT)
            advance_token
            next
          end

          # Unexpected token in block header; continue until body starts or line ends.
          break
        end

        consume(:LBRACE)
        body = parse_body
        consume(:RBRACE) if check?(:RBRACE)

        AST::Block.new(type: type, labels: labels, body: body, comment: comment)
      end

      def parse_body
        items = []

        until eof? || check?(:RBRACE)
          item_comment = consume_trivia
          break if eof? || check?(:RBRACE)

          unless check?(:IDENT)
            advance_token
            next
          end

          if lookahead_type == :EQUALS
            items << parse_attribute(comment: item_comment)
          else
            items << parse_block(comment: item_comment)
          end
        end

        items
      end

      def parse_attribute(comment:)
        key = consume(:IDENT).value
        consume(:EQUALS)
        value = parse_expression_with_fallback(stoppers: %i[COMMENT NEWLINE RBRACE])

        AST::Attribute.new(key: key, value: value, comment: comment)
      end

      def parse_expression_with_fallback(stoppers:)
        start_index = @index
        node = parse_expression
        return node if expression_terminated?(stoppers)

        @index = start_index
        consume_raw_expression(stoppers: stoppers)
      rescue ParseError
        @index = start_index
        consume_raw_expression(stoppers: stoppers)
      end

      def parse_expression
        parse_primary_expression
      end

      def parse_primary_expression
        case peek.type
        when :STRING
          parse_string
        when :HEREDOC
          AST::Literal.new(value: consume(:HEREDOC).value)
        when :NUMBER
          AST::Literal.new(value: consume(:NUMBER).value)
        when :BOOL
          AST::Literal.new(value: consume(:BOOL).value)
        when :LBRACK
          parse_list_expression
        when :LBRACE
          parse_map_expression
        when :IDENT
          parse_identifier_expression
        when :LPAREN
          parse_parenthesized_expression
        else
          raise ParseError, "Unsupported expression token: #{peek.type}"
        end
      end

      def parse_string
        token = consume(:STRING)
        if token.value.include?("${")
          AST::TemplateExpr.new(parts: [token.value])
        else
          AST::Literal.new(value: token.value)
        end
      end

      def parse_parenthesized_expression
        consume(:LPAREN)
        inner = parse_expression_with_fallback(stoppers: %i[COMMENT RPAREN])
        consume(:RPAREN)
        inner
      end

      def parse_list_expression
        consume(:LBRACK)
        elements = []

        until eof? || check?(:RBRACK)
          consume_trivia
          break if check?(:RBRACK)

          elements << parse_expression_with_fallback(stoppers: %i[COMMENT COMMA NEWLINE RBRACK])
          consume_trivia
          advance_token if check?(:COMMA)
        end

        consume(:RBRACK)
        AST::ListExpr.new(elements: elements)
      end

      def parse_map_expression
        consume(:LBRACE)
        pairs = {}

        until eof? || check?(:RBRACE)
          consume_trivia
          break if check?(:RBRACE)

          key = parse_map_key
          if check?(:EQUALS) || check?(:COLON)
            advance_token
          else
            raise ParseError, "Expected '=' or ':' in map expression"
          end

          value = parse_expression_with_fallback(stoppers: %i[COMMENT COMMA NEWLINE RBRACE])
          pairs[key] = value
          consume_trivia
          advance_token if check?(:COMMA)
        end

        consume(:RBRACE)
        AST::MapExpr.new(pairs: pairs)
      end

      def parse_map_key
        case peek.type
        when :IDENT, :STRING
          advance_token.value
        else
          raise ParseError, "Unsupported map key token: #{peek.type}"
        end
      end

      def parse_identifier_expression
        head = consume(:IDENT)
        return AST::Literal.new(value: nil) if head.value == "null"

        if check?(:LPAREN)
          return parse_function_call(head.value)
        end

        expr = AST::Reference.new(parts: [head.value])
        loop do
          if check?(:DOT)
            advance_token
            expr = parse_dot_suffix(expr)
            next
          end

          if check?(:LBRACK)
            advance_token
            index = parse_expression_with_fallback(stoppers: %i[COMMENT RBRACK])
            consume(:RBRACK)
            expr = AST::IndexExpr.new(expr: expr, index: index)
            next
          end

          break
        end

        expr
      end

      def parse_dot_suffix(expr)
        if check?(:STAR)
          advance_token
          attr = nil
          if check?(:DOT)
            advance_token
            attr = consume(:IDENT).value
          end
          return AST::SplatExpr.new(expr: expr, attr: attr)
        end

        part = consume(:IDENT).value
        if expr.is_a?(AST::Reference)
          expr.parts << part
          expr
        else
          AST::Reference.new(parts: [expr, part])
        end
      end

      def parse_function_call(name)
        consume(:LPAREN)
        args = []

        until eof? || check?(:RPAREN)
          consume_trivia
          break if check?(:RPAREN)

          args << parse_expression_with_fallback(stoppers: %i[COMMENT COMMA NEWLINE RPAREN])
          consume_trivia
          advance_token if check?(:COMMA)
        end

        consume(:RPAREN)
        AST::FunctionCall.new(name: name, args: args)
      end

      def consume_raw_expression(stoppers:)
        start_token = peek
        return AST::RawExpr.new(text: "") if start_token.nil? || start_token.type == :EOF

        depth = { paren: 0, brack: 0, brace: 0 }
        first = nil
        last = nil

        until eof?
          token = peek
          break if token.nil? || token.type == :EOF
          break if should_stop_raw?(token, stoppers, depth)

          first ||= token
          last = token
          update_depth!(depth, token)
          advance_token
        end

        text = if first && last
                 @source[first.start_pos...last.end_pos]
               else
                 ""
               end

        AST::RawExpr.new(text: text.to_s.strip)
      end

      def should_stop_raw?(token, stoppers, depth)
        depth.values.all?(&:zero?) && stoppers.include?(token.type)
      end

      def update_depth!(depth, token)
        case token.type
        when :LPAREN
          depth[:paren] += 1
        when :RPAREN
          depth[:paren] -= 1 if depth[:paren].positive?
        when :LBRACK
          depth[:brack] += 1
        when :RBRACK
          depth[:brack] -= 1 if depth[:brack].positive?
        when :LBRACE
          depth[:brace] += 1
        when :RBRACE
          depth[:brace] -= 1 if depth[:brace].positive?
        end
      end

      def expression_terminated?(stoppers)
        return true if eof?

        token = peek
        stoppers.include?(token.type) || token.type == :EOF
      end

      def consume_trivia
        comments = []

        while check?(:NEWLINE) || check?(:COMMENT)
          token = advance_token
          comments << token.value if token.type == :COMMENT
        end

        comments.empty? ? nil : comments.join("\n")
      end

      def block_start?
        check?(:IDENT) && lookahead_type != :EQUALS
      end

      def consume(type)
        token = peek
        if token.nil? || token.type != type
          actual = token&.type || :EOF
          raise ParseError, "Expected #{type}, got #{actual}"
        end

        advance_token
      end

      def check?(type)
        peek&.type == type
      end

      def peek(offset = 0)
        @tokens[@index + offset]
      end

      def lookahead_type
        peek(1)&.type
      end

      def advance_token
        token = @tokens[@index]
        @index += 1
        token
      end

      def eof?
        check?(:EOF)
      end
    end
  end
end
