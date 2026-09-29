module Dovetail
  module Shape
    ElementNode = Struct.new(:tag, :attrs, :children, :line, :col, :self_closing)
    AttrNode = Struct.new(:name, :kind, :value, :line, :col)
    TextNode = Struct.new(:text, :line, :col)
    BlockNode = Struct.new(:keyword, :branches, :line, :col)
    RenderTagNode = Struct.new(:expr, :line, :col)
    HtmlTagNode = Struct.new(:expr, :line, :col)
    ConstTagNode = Struct.new(:expr, :line, :col)
    ExpressionNode = Struct.new(:expr, :line, :col)
    ScriptBlock = Struct.new(:context, :text, :line, :col)
    StyleBlock = Struct.new(:text, :line, :col)
    CodeFragment = Struct.new(:text, :line, :col)

    class SvelteParser
      def self.parse(text)
        new(text).parse_document
      end

      def initialize(text)
        @text = text
        @pos = 0
        @len = text.length
        @line = 1
        @col = 1
        @errors = []
        @unknown_spans = []
        @scripts = []
        @styles = []
        @fragments = []
      end

      def parse_document
        children = parse_children(nil)
        {
          children: children,
          scripts: @scripts,
          styles: @styles,
          fragments: @fragments,
          errors: @errors,
          unknown_spans: @unknown_spans
        }
      end

      private

      def eof?
        @pos >= @len
      end

      def peek(n = 1)
        @text[@pos, n]
      end

      def advance(n)
        n.times do
          break if @pos >= @len
          if @text[@pos] == "\n"
            @line += 1
            @col = 1
          else
            @col += 1
          end
          @pos += 1
        end
      end

      def pos_mark
        [@line, @col]
      end

      def record_error(line, col)
        @errors << { line: line, col: col }
      end

      def parse_children(stop)
        nodes = []
        loop do
          break if eof?
          if peek == "<"
            if peek(4) == "<!--"
              skip_comment
              next
            end
            if peek(2) == "</"
              break
            end
            node = parse_tag
            if node.is_a?(Symbol)
              next
            end
            nodes << node if node
            next
          elsif peek == "{"
            marker = brace_marker
            if marker == :else || marker == :end
              break if stop
              node = parse_stray_brace
              nodes << node if node
              next
            end
            node = parse_brace
            nodes << node if node
            next
          else
            node = parse_text
            nodes << node if node
          end
        end
        nodes
      end

      def brace_marker
        c = @text[@pos + 1]
        return :else if c == ":"
        return :end if c == "/"
        nil
      end

      def parse_stray_brace
        start = pos_mark
        record_error(*start)
        advance(1)
        raw = scan_balanced_braces_content
        advance(1) if peek == "}"
        @unknown_spans << { text: raw, line: start[0], col: start[1] }
        nil
      end

      def skip_comment
        advance(4)
        idx = @text.index("-->", @pos)
        if idx
          advance(idx - @pos + 3)
        else
          advance(@len - @pos)
        end
      end

      def parse_text
        start = pos_mark
        buf = +""
        while !eof? && peek != "<" && peek != "{"
          buf << @text[@pos]
          advance(1)
        end
        return nil if buf.empty?
        TextNode.new(buf, start[0], start[1])
      end

      def scan_name
        start = @pos
        while @pos < @len && @text[@pos] =~ /[A-Za-z0-9:_.\-]/
          advance(1)
        end
        @text[start...@pos]
      end

      def scan_balanced_braces_content
        depth = 0
        buf = +""
        while @pos < @len
          ch = @text[@pos]
          if ch == "'" || ch == '"' || ch == "`"
            buf << scan_string_like(ch)
            next
          end
          if ch == "{"
            depth += 1
            buf << ch
            advance(1)
            next
          end
          if ch == "}"
            break if depth == 0
            depth -= 1
            buf << ch
            advance(1)
            next
          end
          buf << ch
          advance(1)
        end
        buf
      end

      def scan_string_like(quote)
        start = @pos
        advance(1)
        while @pos < @len
          ch = @text[@pos]
          if ch == "\\"
            advance(2)
            next
          end
          if ch == quote
            advance(1)
            break
          end
          if quote == "`" && ch == "$" && @text[@pos + 1] == "{"
            advance(2)
            depth = 1
            while @pos < @len && depth > 0
              c2 = @text[@pos]
              if c2 == "{"
                depth += 1
              elsif c2 == "}"
                depth -= 1
              end
              advance(1)
            end
            next
          end
          advance(1)
        end
        @text[start...@pos]
      end

      def register_fragment(text, line, col)
        @fragments << CodeFragment.new(text, line, col)
      end

      def parse_tag
        start = pos_mark
        advance(1)
        name = scan_name
        if name.empty?
          record_error(*start)
          advance(1)
          return nil
        end
        attrs = []
        loop do
          skip_ws
          break if eof?
          if peek(2) == "/>" || peek == ">"
            break
          end
          if peek == "{"
            attr_start = pos_mark
            advance(1)
            raw = scan_balanced_braces_content
            advance(1) if peek == "}"
            if raw.start_with?("...")
              expr = raw[3..-1]
              register_fragment(expr, attr_start[0], attr_start[1] + 4)
              attrs << AttrNode.new("...spread", :spread, expr, attr_start[0], attr_start[1])
            else
              register_fragment(raw, attr_start[0], attr_start[1] + 1)
              attrs << AttrNode.new(raw.strip, :shorthand, raw, attr_start[0], attr_start[1])
            end
            next
          end
          attr_name_start = pos_mark
          attr_name = +""
          while @pos < @len && @text[@pos] !~ /[\s=\/>]/
            attr_name << @text[@pos]
            advance(1)
          end
          if attr_name.empty?
            advance(1)
            next
          end
          skip_ws
          if peek == "="
            advance(1)
            skip_ws
            if peek == "'" || peek == '"'
              quote = peek
              val_start = pos_mark
              raw = scan_string_like(quote)
              value = raw[1..-2]
              if value.include?("{")
                extract_mixed_expressions(value, val_start[0], val_start[1] + 1)
                attrs << AttrNode.new(attr_name, :mixed, value, attr_name_start[0], attr_name_start[1])
              else
                attrs << AttrNode.new(attr_name, :static, value, attr_name_start[0], attr_name_start[1])
              end
            elsif peek == "{"
              val_start = pos_mark
              advance(1)
              raw = scan_balanced_braces_content
              advance(1) if peek == "}"
              register_fragment(raw, val_start[0], val_start[1] + 1)
              attrs << AttrNode.new(attr_name, :expression, raw, attr_name_start[0], attr_name_start[1])
            else
              bare_start = @pos
              while @pos < @len && @text[@pos] !~ /[\s\/>]/
                advance(1)
              end
              value = @text[bare_start...@pos]
              attrs << AttrNode.new(attr_name, :static, value, attr_name_start[0], attr_name_start[1])
            end
          else
            attrs << AttrNode.new(attr_name, :boolean, nil, attr_name_start[0], attr_name_start[1])
          end
        end
        self_closing = false
        if peek(2) == "/>"
          self_closing = true
          advance(2)
        elsif peek == ">"
          advance(1)
        end
        void_el = %w[br img input hr meta link area base col embed param source track wbr].include?(name.downcase)
        if self_closing || void_el
          return ElementNode.new(name, attrs, [], start[0], start[1], true)
        end
        if name.downcase == "script"
          text_start = pos_mark
          idx = @text[@pos..-1] =~ /<\/script\s*>/i
          if idx
            body = @text[@pos, idx]
            advance(idx)
            advance(@text[@pos..-1][/\A<\/script\s*>/i].length)
          else
            body = @text[@pos..-1]
            advance(@len - @pos)
          end
          context = attrs.find { |a| a.name == "context" }&.value == "module" ? :module : :instance
          @scripts << ScriptBlock.new(context, body, text_start[0], text_start[1])
          register_fragment(body, text_start[0], text_start[1])
          return :handled
        end
        if name.downcase == "style"
          text_start = pos_mark
          idx = @text[@pos..-1] =~ /<\/style\s*>/i
          if idx
            body = @text[@pos, idx]
            advance(idx)
            advance(@text[@pos..-1][/\A<\/style\s*>/i].length)
          else
            body = @text[@pos..-1]
            advance(@len - @pos)
          end
          @styles << StyleBlock.new(body, text_start[0], text_start[1])
          return :handled
        end
        children = parse_children(:tag)
        if peek(2) == "</"
          advance(2)
          scan_name
          skip_ws
          advance(1) if peek == ">"
        end
        ElementNode.new(name, attrs, children, start[0], start[1], false)
      end

      def extract_mixed_expressions(value, base_line, base_col)
        i = 0
        line = base_line
        col = base_col
        while i < value.length
          ch = value[i]
          if ch == "{"
            depth = 1
            start = i + 1
            j = i + 1
            eline = line
            ecol = col + 1
            while j < value.length && depth > 0
              c2 = value[j]
              if c2 == "{"
                depth += 1
              elsif c2 == "}"
                depth -= 1
              end
              j += 1
            end
            expr = value[start...(j - 1)]
            register_fragment(expr, eline, ecol)
            (start...j).each do |k|
              if value[k] == "\n"
                line += 1
                col = 1
              else
                col += 1
              end
            end
            i = j
            next
          end
          if ch == "\n"
            line += 1
            col = 1
          else
            col += 1
          end
          i += 1
        end
      end

      def skip_ws
        while @pos < @len && @text[@pos] =~ /[ \t\r\n]/
          advance(1)
        end
      end

      def parse_brace
        start = pos_mark
        advance(1)
        c = peek
        if c == "#"
          advance(1)
          return parse_block(start)
        end
        if c == "@"
          advance(1)
          kw_start_pos = @pos
          kw = scan_word
          skip_ws
          expr_start = pos_mark
          raw = scan_balanced_braces_content
          advance(1) if peek == "}"
          register_fragment(raw, expr_start[0], expr_start[1])
          case kw
          when "render"
            return RenderTagNode.new(raw, start[0], start[1])
          when "html"
            return HtmlTagNode.new(raw, start[0], start[1])
          when "const"
            return ConstTagNode.new(raw, start[0], start[1])
          else
            record_error(*start)
            return nil
          end
        end
        expr_start = pos_mark
        raw = scan_balanced_braces_content
        advance(1) if peek == "}"
        register_fragment(raw, expr_start[0], expr_start[1])
        ExpressionNode.new(raw, start[0], start[1])
      end

      def scan_word
        start = @pos
        while @pos < @len && @text[@pos] =~ /[a-zA-Z]/
          advance(1)
        end
        @text[start...@pos]
      end

      def parse_block(start)
        keyword = scan_word
        skip_ws
        expr_start = pos_mark
        raw = scan_balanced_braces_content
        advance(1) if peek == "}"
        register_fragment(raw, expr_start[0], expr_start[1]) unless raw.strip.empty?
        branches = [{ kind: keyword, expr: raw, children: [] }]
        loop do
          branches.last[:children] = parse_children(:block)
          if eof?
            record_error(*pos_mark)
            break
          end
          marker = brace_marker
          if marker == :else
            advance(1)
            advance(1)
            sub_kw_start = @pos
            skip_ws
            sub_kw = scan_word
            skip_ws
            sub_expr = ""
            unless peek == "}"
              sub_expr_start = pos_mark
              sub_expr = scan_balanced_braces_content
              register_fragment(sub_expr, sub_expr_start[0], sub_expr_start[1]) unless sub_expr.strip.empty?
            end
            advance(1) if peek == "}"
            branches << { kind: sub_kw.empty? ? "else" : sub_kw, expr: sub_expr, children: [] }
            next
          elsif marker == :end
            advance(1)
            advance(1)
            scan_word
            advance(1) if peek == "}"
            break
          else
            record_error(*pos_mark)
            break
          end
        end
        BlockNode.new(keyword, branches, start[0], start[1])
      end
    end
  end
end
