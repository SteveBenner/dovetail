module Dovetail
  module Shape
    class JSToken
      attr_reader :type, :value, :line, :col

      def initialize(type, value, line, col)
        @type = type
        @value = value
        @line = line
        @col = col
      end
    end

    class JSTokenizer
      PUNCTUATORS = %w[?. ... => === !== == != <= >= && || ?? ( ) { } [ ] . , ; : = < > + - * / % ! & | ^ ~ ? \\].freeze

      def initialize(text, base_line, base_col)
        @text = text
        @pos = 0
        @len = text.length
        @line = base_line
        @col = base_col
      end

      def tokens
        out = []
        prev_significant = nil
        while @pos < @len
          skip_whitespace
          break if @pos >= @len
          start_line = @line
          start_col = @col
          ch = @text[@pos]
          if ch == "/" && @text[@pos + 1] == "/"
            skip_line_comment
            next
          end
          if ch == "/" && @text[@pos + 1] == "*"
            skip_block_comment
            next
          end
          if ch == "'" || ch == '"'
            value = scan_string(ch)
            tok = JSToken.new(:string, value, start_line, start_col)
            out << tok
            prev_significant = tok
            next
          end
          if ch == "`"
            value = scan_template
            tok = JSToken.new(:template, value, start_line, start_col)
            out << tok
            prev_significant = tok
            next
          end
          if ch == "/" && regex_allowed?(prev_significant)
            value = scan_regex
            if value
              tok = JSToken.new(:regex, value, start_line, start_col)
              out << tok
              prev_significant = tok
              next
            end
          end
          if ch =~ /[A-Za-z_$]/
            value = scan_identifier
            tok = JSToken.new(:identifier, value, start_line, start_col)
            out << tok
            prev_significant = tok
            next
          end
          if ch =~ /[0-9]/
            value = scan_number
            tok = JSToken.new(:number, value, start_line, start_col)
            out << tok
            prev_significant = tok
            next
          end
          punct = scan_punctuator
          if punct
            tok = JSToken.new(:punct, punct, start_line, start_col)
            out << tok
            prev_significant = tok
            next
          end
          advance(1)
        end
        out
      end

      private

      def regex_allowed?(prev)
        return true if prev.nil?
        return false if prev.type == :identifier && !%w[return typeof instanceof in of new delete void yield await].include?(prev.value)
        return false if prev.type == :number || prev.type == :string || prev.type == :template || prev.type == :regex
        return false if prev.type == :punct && [")", "]", "}"].include?(prev.value)
        true
      end

      def scan_regex
        start = @pos
        p = @pos + 1
        in_class = false
        while p < @len
          c = @text[p]
          if c == "\\"
            p += 2
            next
          end
          if c == "["
            in_class = true
          elsif c == "]"
            in_class = false
          elsif c == "/" && !in_class
            p += 1
            break
          elsif c == "\n"
            return nil
          end
          p += 1
        end
        while p < @len && @text[p] =~ /[a-z]/
          p += 1
        end
        text = @text[start...p]
        advance(text.length)
        text
      end

      def skip_whitespace
        while @pos < @len && @text[@pos] =~ /[ \t\r\n]/
          advance(1)
        end
      end

      def skip_line_comment
        while @pos < @len && @text[@pos] != "\n"
          advance(1)
        end
      end

      def skip_block_comment
        advance(2)
        while @pos < @len && !(@text[@pos] == "*" && @text[@pos + 1] == "/")
          advance(1)
        end
        advance(2) if @pos < @len
      end

      def scan_string(quote)
        start = @pos
        advance(1)
        while @pos < @len
          c = @text[@pos]
          if c == "\\"
            advance(2)
            next
          end
          if c == quote
            advance(1)
            break
          end
          advance(1)
        end
        @text[start...@pos]
      end

      def scan_template
        start = @pos
        advance(1)
        depth = 0
        while @pos < @len
          c = @text[@pos]
          if c == "\\"
            advance(2)
            next
          end
          if c == "`" && depth == 0
            advance(1)
            break
          end
          if c == "$" && @text[@pos + 1] == "{"
            depth += 1
            advance(2)
            next
          end
          if depth > 0
            if c == "{"
              depth += 1
              advance(1)
              next
            end
            if c == "}"
              depth -= 1
              advance(1)
              next
            end
          end
          advance(1)
        end
        @text[start...@pos]
      end

      def scan_identifier
        start = @pos
        while @pos < @len && @text[@pos] =~ /[A-Za-z0-9_$]/
          advance(1)
        end
        @text[start...@pos]
      end

      def scan_number
        start = @pos
        while @pos < @len && @text[@pos] =~ /[0-9.eExXa-fA-F+-]/
          break if %w[+ -].include?(@text[@pos]) && !%w[e E].include?(@text[@pos - 1])
          advance(1)
        end
        @text[start...@pos]
      end

      def scan_punctuator
        %w[?. ... => === !== == != <= >=].each do |p|
          if @text[@pos, p.length] == p
            advance(p.length)
            return p
          end
        end
        ch = @text[@pos]
        return nil unless PUNCTUATORS.include?(ch)
        advance(1)
        ch
      end

      def advance(n)
        n.times do
          if @pos < @len
            if @text[@pos] == "\n"
              @line += 1
              @col = 1
            else
              @col += 1
            end
            @pos += 1
          end
        end
      end
    end

    Access = Struct.new(:chain, :alias_root, :call, :call_args, :assigned, :new_expr, :computed, :line, :col)
    ImportFact = Struct.new(:kind, :names, :pairs, :source, :line, :col)
    DynamicImportFact = Struct.new(:source, :literal, :line, :col)

    class JSScanner
      GLOBAL_ROOTS = %w[window document globalThis self navigator history location localStorage sessionStorage indexedDB].freeze
      GLOBAL_FUNCTIONS = %w[setInterval setTimeout requestAnimationFrame requestIdleCallback fetch XMLHttpRequest EventSource WebSocket postMessage eval Function addEventListener removeEventListener dispatchEvent].freeze

      def initialize(scope)
        @scope = scope
      end

      def scan(text, base_line, base_col)
        tokens = JSTokenizer.new(text, base_line, base_col).tokens
        imports = []
        accesses = []
        dynamic_imports = []
        @pending_accesses = accesses
        @pending_dynamic_imports = dynamic_imports
        i = 0
        n = tokens.length
        while i < n
          tok = tokens[i]
          if tok.type == :identifier && tok.value == "import"
            if tokens[i + 1] && tokens[i + 1].type == :punct && tokens[i + 1].value == "("
              fact, i = scan_dynamic_import(tokens, i)
              dynamic_imports << fact if fact
              next
            end
            fact, i = scan_import(tokens, i)
            imports << fact if fact
            next
          end
          if tok.type == :identifier && %w[const let var].include?(tok.value)
            i = scan_declaration(tokens, i)
            next
          end
          if tok.type == :identifier && identifier_start_of_chain?(tokens, i)
            access, i = scan_chain(tokens, i)
            accesses << access if access
            next
          end
          i += 1
        end
        [imports, accesses, dynamic_imports]
      end

      private

      def identifier_start_of_chain?(tokens, i)
        prev = tokens[i - 1]
        return false if prev && prev.type == :punct && (prev.value == "." || prev.value == "?.")
        true
      end

      def scan_dynamic_import(tokens, i)
        start = tokens[i]
        i += 1
        return [nil, i] unless tokens[i] && tokens[i].type == :punct && tokens[i].value == "("
        i += 1
        depth = 1
        arg_tokens = []
        while i < tokens.length && depth > 0
          if tokens[i].type == :punct && tokens[i].value == "("
            depth += 1
          elsif tokens[i].type == :punct && tokens[i].value == ")"
            depth -= 1
            i += 1 if depth == 0
            next if depth == 0
          end
          arg_tokens << tokens[i]
          i += 1
        end
        meaningful = arg_tokens.reject { |t| t.type == :comment }
        if meaningful.size == 1 && meaningful.first.type == :string
          source = strip_quotes(meaningful.first.value)
          [DynamicImportFact.new(source, true, start.line, start.col), i]
        else
          [DynamicImportFact.new(nil, false, start.line, start.col), i]
        end
      end

      def scan_import(tokens, i)
        start = tokens[i]
        i += 1
        pairs = []
        kind = :named
        while i < tokens.length
          tok = tokens[i]
          if tok.type == :string
            source = strip_quotes(tok.value)
            names = pairs.map { |p| p[1] }
            return [ImportFact.new(kind, names, pairs, source, start.line, start.col), i + 1]
          end
          if tok.type == :identifier && tok.value == "from"
            i += 1
            next
          end
          if tok.type == :identifier && tok.value == "type" && pairs.empty?
            i += 1
            next
          end
          if tok.type == :punct && tok.value == "*"
            kind = :namespace
            i += 1
            if tokens[i] && tokens[i].type == :identifier && tokens[i].value == "as"
              i += 1
              if tokens[i] && tokens[i].type == :identifier
                pairs << ["*", tokens[i].value]
                i += 1
              end
            end
            next
          end
          if tok.type == :punct && tok.value == "{"
            i += 1
            while i < tokens.length && !(tokens[i].type == :punct && tokens[i].value == "}")
              if tokens[i].type == :identifier && tokens[i].value == "type"
                i += 1
                next
              end
              if tokens[i].type == :identifier
                orig = tokens[i].value
                i += 1
                local = orig
                if tokens[i] && tokens[i].type == :identifier && tokens[i].value == "as"
                  i += 1
                  if tokens[i] && tokens[i].type == :identifier
                    local = tokens[i].value
                    i += 1
                  end
                end
                pairs << [orig, local]
              else
                i += 1
                next
              end
              if tokens[i] && tokens[i].type == :punct && tokens[i].value == ","
                i += 1
              end
            end
            i += 1 if tokens[i] && tokens[i].type == :punct && tokens[i].value == "}"
            next
          end
          if tok.type == :identifier
            pairs << [nil, tok.value]
            i += 1
            next
          end
          i += 1
        end
        [nil, i]
      end

      def resolve_root(name)
        if @scope[:aliases].key?(name) && !@scope[:shadowed].include?(name)
          @scope[:aliases][name]
        elsif global_name?(name) && !@scope[:shadowed].include?(name)
          [name]
        end
      end

      def scan_declaration(tokens, i)
        i += 1
        if tokens[i] && tokens[i].type == :punct && tokens[i].value == "{"
          i += 1
          pairs = []
          while i < tokens.length && !(tokens[i].type == :punct && tokens[i].value == "}")
            if tokens[i].type == :identifier
              prop = tokens[i].value
              i += 1
              local = prop
              if tokens[i] && tokens[i].type == :punct && tokens[i].value == ":"
                i += 1
                if tokens[i] && tokens[i].type == :identifier
                  local = tokens[i].value
                  i += 1
                end
              end
              pairs << [prop, local]
            else
              i += 1
            end
          end
          i += 1
          if tokens[i] && tokens[i].type == :punct && tokens[i].value == "="
            i += 1
            root_chain, i = read_chain_tokens(tokens, i)
            root_resolved = root_chain ? resolve_root(root_chain.first) : nil
            if root_resolved
              full_root = root_resolved + root_chain.drop(1)
              pairs.each do |prop, local|
                @scope[:aliases][local] = full_root + [prop]
              end
            else
              pairs.each { |_prop, local| @scope[:shadowed] << local }
            end
          end
          return i
        end
        return i unless tokens[i] && tokens[i].type == :identifier
        name = tokens[i].value
        i += 1
        unless tokens[i] && tokens[i].type == :punct && tokens[i].value == "="
          @scope[:shadowed] << name
          return i
        end
        i += 1
        init_start = tokens[i]
        if init_start && init_start.type == :identifier && init_start.value == "import" &&
           tokens[i + 1] && tokens[i + 1].type == :punct && tokens[i + 1].value == "("
          fact, i = scan_dynamic_import(tokens, i)
          @pending_dynamic_imports << fact if fact && @pending_dynamic_imports
          @scope[:shadowed] << name
          return i
        end
        parsed = parse_access_chain(tokens, i)
        unless parsed
          @scope[:shadowed] << name
          return i
        end
        i = parsed[:end_index]
        chain = parsed[:chain]
        resolved = resolve_root(chain.first)
        if resolved
          full = resolved + chain.drop(1)
          @scope[:aliases][name] = full unless parsed[:call] || parsed[:new_expr]
          @scope[:shadowed] << name if parsed[:call] || parsed[:new_expr]
          read_access = Access.new(chain, resolved, parsed[:call], parsed[:call_args], false, parsed[:new_expr], parsed[:computed], init_start.line, init_start.col)
          @pending_accesses << read_access if @pending_accesses
        else
          @scope[:shadowed] << name
        end
        i
      end

      def read_chain_tokens(tokens, i)
        return [nil, i] unless tokens[i] && tokens[i].type == :identifier
        chain = [tokens[i].value]
        i += 1
        loop do
          if tokens[i] && tokens[i].type == :punct && (tokens[i].value == "." || tokens[i].value == "?.")
            i += 1
            if tokens[i] && tokens[i].type == :identifier
              chain << tokens[i].value
              i += 1
              next
            end
          end
          break
        end
        [chain, i]
      end

      def parse_access_chain(tokens, i)
        start = tokens[i]
        return nil unless start
        new_expr = false
        if start.type == :identifier && start.value == "new"
          new_expr = true
          i += 1
          start = tokens[i]
          return nil unless start && start.type == :identifier
        end
        return nil unless start.type == :identifier
        chain = [start.value]
        i += 1
        computed = false
        loop do
          tok = tokens[i]
          break unless tok
          if tok.type == :punct && (tok.value == "." || tok.value == "?.")
            i += 1
            if tokens[i] && tokens[i].type == :identifier
              chain << tokens[i].value
              i += 1
              next
            end
            break
          elsif tok.type == :punct && tok.value == "["
            computed = true
            depth = 1
            i += 1
            while i < tokens.length && depth > 0
              if tokens[i].type == :punct && tokens[i].value == "["
                depth += 1
              elsif tokens[i].type == :punct && tokens[i].value == "]"
                depth -= 1
              end
              i += 1
            end
          else
            break
          end
        end
        call = false
        call_args = []
        if tokens[i] && tokens[i].type == :punct && tokens[i].value == "("
          call = true
          i += 1
          depth = 1
          arg_tokens = []
          while i < tokens.length && depth > 0
            if tokens[i].type == :punct && tokens[i].value == "("
              depth += 1
            elsif tokens[i].type == :punct && tokens[i].value == ")"
              depth -= 1
              i += 1 if depth == 0
              next if depth == 0
            end
            arg_tokens << tokens[i]
            i += 1
          end
          call_args = split_args(arg_tokens)
        end
        { start: start, chain: chain, call: call, call_args: call_args, new_expr: new_expr, computed: computed, end_index: i }
      end

      def scan_chain(tokens, i)
        parsed = parse_access_chain(tokens, i)
        return [nil, i + 1] unless parsed
        i = parsed[:end_index]
        assigned = false
        if !parsed[:call] && tokens[i] && tokens[i].type == :punct && tokens[i].value == "="
          nxt = tokens[i + 1]
          unless nxt && nxt.type == :punct && nxt.value == "="
            assigned = true
            i += 1
          end
        end
        alias_root = resolve_root(parsed[:chain].first)
        access = Access.new(parsed[:chain], alias_root, parsed[:call], parsed[:call_args], assigned, parsed[:new_expr], parsed[:computed], parsed[:start].line, parsed[:start].col)
        [access, i]
      end

      def split_args(tokens)
        args = []
        current = []
        depth = 0
        tokens.each do |tok|
          if tok.type == :punct && %w[( [ {].include?(tok.value)
            depth += 1
          elsif tok.type == :punct && [")", "]", "}"].include?(tok.value)
            depth -= 1
          end
          if tok.type == :punct && tok.value == "," && depth == 0
            args << current
            current = []
          else
            current << tok
          end
        end
        args << current unless current.empty?
        args
      end

      def global_name?(name)
        GLOBAL_ROOTS.include?(name) || GLOBAL_FUNCTIONS.include?(name)
      end

      def strip_quotes(str)
        str[1..-2]
      end
    end
  end
end
