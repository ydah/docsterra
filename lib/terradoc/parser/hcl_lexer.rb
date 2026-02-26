# frozen_string_literal: true

module Terradoc
  module Parser
    class HclLexer
      Token = Struct.new(
        :type,
        :value,
        :lexeme,
        :line,
        :column,
        :start_pos,
        :end_pos,
        keyword_init: true
      )

      SINGLE_CHAR_TOKENS = {
        "{" => :LBRACE,
        "}" => :RBRACE,
        "[" => :LBRACK,
        "]" => :RBRACK,
        "(" => :LPAREN,
        ")" => :RPAREN,
        "=" => :EQUALS,
        "," => :COMMA,
        "." => :DOT
      }.freeze

      EXTRA_TOKENS = {
        "?" => :QUESTION,
        ":" => :COLON,
        "+" => :PLUS,
        "-" => :MINUS,
        "*" => :STAR,
        "/" => :SLASH,
        "%" => :PERCENT,
        "!" => :BANG,
        ">" => :GT,
        "<" => :LT
      }.freeze

      def initialize(text = nil)
        @text = text
      end

      def tokenize(text = @text)
        raise ArgumentError, "text is required" if text.nil?

        setup(text)
        tokens = []

        until eof?
          case current_char
          when " ", "\t", "\r"
            advance
          when "\n"
            tokens << build_token(:NEWLINE, "\n", consume_newline)
          when "#"
            tokens << consume_line_comment("#")
          when "/"
            tokens << if peek_char == "/"
                        consume_line_comment("//")
                      elsif peek_char == "*"
                        consume_block_comment
                      else
                        consume_single_char_token(EXTRA_TOKENS.fetch("/"))
                      end
          when "\""
            tokens << consume_string
          when "<"
            tokens << if peek_char == "<"
                        consume_heredoc
                      else
                        consume_single_char_token(EXTRA_TOKENS.fetch("<"))
                      end
          else
            tokens << consume_token
          end
        end

        tokens << Token.new(
          type: :EOF,
          value: nil,
          lexeme: "",
          line: @line,
          column: @column,
          start_pos: @index,
          end_pos: @index
        )
        tokens
      end

      private

      def setup(text)
        @text = text
        @index = 0
        @line = 1
        @column = 1
      end

      def consume_token
        return consume_number if digit?(current_char)
        return consume_identifier if identifier_start?(current_char)
        return consume_single_char_token(SINGLE_CHAR_TOKENS.fetch(current_char)) if SINGLE_CHAR_TOKENS.key?(current_char)
        return consume_single_char_token(EXTRA_TOKENS.fetch(current_char)) if EXTRA_TOKENS.key?(current_char)

        consume_unknown
      end

      def consume_single_char_token(type)
        start_pos = @index
        start_line = @line
        start_column = @column
        advance
        build_token(type, @text[start_pos...@index], [start_pos, start_line, start_column])
      end

      def consume_newline
        start_pos = @index
        start_line = @line
        start_column = @column
        advance
        [start_pos, start_line, start_column]
      end

      def consume_line_comment(prefix)
        start_pos = @index
        start_line = @line
        start_column = @column
        advance(prefix.length)
        advance until eof? || current_char == "\n"
        lexeme = @text[start_pos...@index]
        value = lexeme.delete_prefix(prefix).strip
        Token.new(
          type: :COMMENT,
          value: value,
          lexeme: lexeme,
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def consume_block_comment
        start_pos = @index
        start_line = @line
        start_column = @column
        advance(2)

        until eof?
          if current_char == "*" && peek_char == "/"
            advance(2)
            break
          end

          advance
        end

        lexeme = @text[start_pos...@index]
        value = lexeme.sub(%r{\A/\*}, "").sub(%r{\*/\z}, "").strip
        Token.new(
          type: :COMMENT,
          value: value,
          lexeme: lexeme,
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def consume_string
        start_pos = @index
        start_line = @line
        start_column = @column
        advance # opening quote

        content = +""
        until eof?
          char = current_char
          if char == "\\"
            content << char
            advance
            break if eof?

            content << current_char
            advance
            next
          end

          if char == "\""
            advance
            break
          end

          content << char
          advance
        end

        Token.new(
          type: :STRING,
          value: content,
          lexeme: @text[start_pos...@index],
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def consume_heredoc
        start_pos = @index
        start_line = @line
        start_column = @column
        advance(2) # <<
        advance if current_char == "-"

        header_delimiter_start = @index
        advance while !eof? && current_char != "\n"
        header_delimiter = @text[header_delimiter_start...@index].strip
        indented = @text[start_pos...header_delimiter_start].end_with?("<<-")

        advance if current_char == "\n"

        content = +""
        loop do
          break if eof?

          line_start = @index
          advance while !eof? && current_char != "\n"
          line_text = @text[line_start...@index]

          match = indented ? line_text.strip == header_delimiter : line_text == header_delimiter
          if !header_delimiter.empty? && match
            advance if current_char == "\n"
            break
          end

          content << line_text
          if current_char == "\n"
            content << "\n"
            advance
          end
        end

        Token.new(
          type: :HEREDOC,
          value: content,
          lexeme: @text[start_pos...@index],
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def consume_number
        start_pos = @index
        start_line = @line
        start_column = @column

        advance while digit?(current_char)
        if current_char == "." && digit?(peek_char)
          advance
          advance while digit?(current_char)
        end

        lexeme = @text[start_pos...@index]
        value = lexeme.include?(".") ? lexeme.to_f : lexeme.to_i
        Token.new(
          type: :NUMBER,
          value: value,
          lexeme: lexeme,
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def consume_identifier
        start_pos = @index
        start_line = @line
        start_column = @column
        advance while identifier_part?(current_char)
        lexeme = @text[start_pos...@index]

        if %w[true false].include?(lexeme)
          type = :BOOL
          value = lexeme == "true"
        else
          type = :IDENT
          value = lexeme
        end

        Token.new(
          type: type,
          value: value,
          lexeme: lexeme,
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def consume_unknown
        start_pos = @index
        start_line = @line
        start_column = @column
        char = current_char
        advance
        Token.new(
          type: :UNKNOWN,
          value: char,
          lexeme: char,
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def build_token(type, value, triple)
        start_pos, start_line, start_column = triple
        Token.new(
          type: type,
          value: value,
          lexeme: @text[start_pos...@index],
          line: start_line,
          column: start_column,
          start_pos: start_pos,
          end_pos: @index
        )
      end

      def current_char
        @text[@index]
      end

      def peek_char(offset = 1)
        @text[@index + offset]
      end

      def advance(count = 1)
        count.times do
          break if eof?

          if current_char == "\n"
            @line += 1
            @column = 1
          else
            @column += 1
          end
          @index += 1
        end
      end

      def eof?
        @index >= @text.length
      end

      def digit?(char)
        !char.nil? && char >= "0" && char <= "9"
      end

      def identifier_start?(char)
        !char.nil? && ((char >= "a" && char <= "z") || (char >= "A" && char <= "Z") || char == "_")
      end

      def identifier_part?(char)
        identifier_start?(char) || digit?(char) || char == "-"
      end
    end
  end
end
