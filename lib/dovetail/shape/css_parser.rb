require "strscan"

module Dovetail
  module Shape
    class CssParser
      Rule = Struct.new(:selector, :declarations, :line, :col)
      Declaration = Struct.new(:property, :value, :important, :line, :col)

      def self.parse(text, base_line: 1, base_col: 1)
        new(text, base_line, base_col).parse_stylesheet
      end

      def self.parse_declarations(text, base_line: 1, base_col: 1)
        new(text, base_line, base_col).parse_declaration_list
      end

      def initialize(text, base_line, base_col)
        @s = StringScanner.new(text)
        @line = base_line
        @col = base_col
      end

      def parse_stylesheet
        rules = []
        loop do
          skip_ws_comments
          break if @s.eos?
          break if @s.peek(1) == "}"
          start_line = @line
          start_col = @col
          if @s.peek(1) == "@"
            prelude = scan_until_top_level(["{", ";"])
            break if @s.eos? && prelude == ""
            if @s.peek(1) == "{"
              consume_char
              nested = parse_stylesheet
              skip_ws_comments
              consume_char if @s.peek(1) == "}"
              rules.concat(nested)
            elsif @s.peek(1) == ";"
              consume_char
            else
              break
            end
            next
          end
          selector = scan_until_top_level(["{"])
          break if @s.eos?
          consume_char
          declarations = parse_declarations_block
          rules << Rule.new(selector.strip, declarations, start_line, start_col)
        end
        rules
      end

      def parse_declarations_block
        decls = []
        loop do
          skip_ws_comments
          break if @s.eos?
          if @s.peek(1) == "}"
            consume_char
            break
          end
          prop_line = @line
          prop_col = @col
          prop = scan_until_top_level([":", ";", "}"])
          break if @s.eos?
          if @s.peek(1) != ":"
            consume_char
            next
          end
          consume_char
          value_raw = scan_until_top_level([";", "}"])
          important = !!(value_raw =~ /!\s*important\s*\z/i)
          value = value_raw.sub(/!\s*important\s*\z/i, "").strip
          decls << Declaration.new(prop.strip, value, important, prop_line, prop_col) unless prop.strip.empty?
          skip_ws_comments
          consume_char if @s.peek(1) == ";"
        end
        decls
      end

      def parse_declaration_list
        decls = []
        loop do
          skip_ws_comments
          break if @s.eos?
          prop_line = @line
          prop_col = @col
          prop = scan_until_top_level([":", ";"])
          break if @s.eos? || @s.peek(1) != ":"
          consume_char
          value_raw = scan_until_top_level([";"])
          important = !!(value_raw =~ /!\s*important\s*\z/i)
          value = value_raw.sub(/!\s*important\s*\z/i, "").strip
          decls << Declaration.new(prop.strip, value, important, prop_line, prop_col) unless prop.strip.empty?
          skip_ws_comments
          consume_char if @s.peek(1) == ";"
        end
        decls
      end

      private

      def skip_ws_comments
        loop do
          matched = @s.scan(/[ \t\r\n]+/)
          if matched
            advance(matched)
            next
          end
          if @s.peek(2) == "/*"
            scan_block_comment
            next
          end
          break
        end
      end

      def scan_block_comment
        start = @s.pos
        @s.pos += 2
        idx = @s.string.index("*/", @s.pos)
        if idx
          text = @s.string[start...(idx + 2)]
          @s.pos = idx + 2
        else
          text = @s.string[start..-1]
          @s.pos = @s.string.length
        end
        advance(text)
      end

      def scan_string(quote)
        start = @s.pos
        @s.pos += 1
        while @s.pos < @s.string.length
          ch = @s.string[@s.pos]
          if ch == "\\"
            @s.pos += 2
            next
          end
          if ch == quote
            @s.pos += 1
            break
          end
          @s.pos += 1
        end
        text = @s.string[start...@s.pos]
        advance(text)
        text
      end

      def consume_char
        ch = @s.string[@s.pos]
        @s.pos += 1
        advance(ch)
        ch
      end

      def scan_until_top_level(stop_chars)
        buf = +""
        depth = 0
        while @s.pos < @s.string.length
          ch = @s.string[@s.pos]
          if ch == "'" || ch == '"'
            buf << scan_string(ch)
            next
          end
          if ch == "/" && @s.string[@s.pos + 1] == "*"
            scan_block_comment
            next
          end
          if ch == "("
            depth += 1
            buf << consume_char
            next
          end
          if ch == ")"
            depth -= 1
            buf << consume_char
            next
          end
          if depth <= 0 && stop_chars.include?(ch)
            break
          end
          buf << consume_char
        end
        buf
      end

      def advance(str)
        return if str.nil? || str.empty?
        parts = str.split("\n", -1)
        if parts.size > 1
          @line += parts.size - 1
          @col = parts.last.length + 1
        else
          @col += str.length
        end
      end
    end
  end
end
