require "ripper"

module Dovetail
  module Contract
    module RipperCheck
      DSL_NAMES = %w[
        contract type field operation emits consumes panel depends_on slot view
        capability route prop tokens storage_key shortcut overlay list map one_of ref
      ].freeze

      SCALARS = %w[String Integer Decimal Boolean Date DateTime Id Money Percent Url Email].freeze

      KEYWORD_LITERALS = %w[true false nil].freeze

      module_function

      def check!(source, path)
        sexp = ::Ripper.sexp(source)
        if sexp.nil?
          raise ::Dovetail::Error.new("D-CON-001", "#{path}: could not parse the contract file")
        end
        visit(sexp, path)
      end

      def fail!(path, line, message)
        raise ::Dovetail::Error.new("D-CON-001", "#{path}:#{line || "?"}: #{message}")
      end

      def line_of(node)
        return nil unless node.is_a?(::Array)
        if node[0].is_a?(::Symbol) && node[0].to_s.start_with?("@")
          pos = node[2]
          return pos[0] if pos.is_a?(::Array)
        end
        node.each do |child|
          found = line_of(child)
          return found if found
        end
        nil
      end

      def visit(node, path)
        return if node.nil?
        return unless node.is_a?(::Array)
        unless node[0].is_a?(::Symbol)
          node.each { |child| visit(child, path) }
          return
        end
        case node[0]
        when :program
          visit(node[1], path)
        when :void_stmt
          nil
        when :bodystmt
          visit(node[1], path)
          fail!(path, line_of(node), "rescue, else and ensure are not allowed") if node[2] || node[3] || node[4]
        when :arg_paren
          visit(node[1], path)
        when :args_add_block
          visit(node[1], path)
          fail!(path, line_of(node), "block argument forwarding is not allowed") if node[2] != false
        when :args_add
          visit(node[1], path)
          visit(node[2], path)
        when :args_new
          nil
        when :bare_assoc_hash
          visit_assocs(node[1], path)
        when :assoclist_from_args
          visit_assocs(node[1], path)
        when :hash
          visit(node[1], path)
        when :array
          visit(node[1], path)
        when :assoc_new
          key = node[1]
          unless key.is_a?(::Array) && %i[@label symbol_literal dyna_symbol].include?(key[0])
            fail!(path, line_of(key), "hash keys must be symbols or labels")
          end
          visit(key, path) if key[0] == :dyna_symbol
          visit(node[2], path)
        when :symbol_literal
          visit(node[1], path)
        when :symbol
          nil
        when :dyna_symbol
          plain_string(node, path)
        when :string_literal
          plain_string(node, path)
        when :@tstring_content, :@ident, :@const, :@label, :@int, :@float, :@CHAR,
             :@kw, :@period, :@op, :@gvar, :@ivar
          nil
        when :var_ref
          visit_var_ref(node[1], path)
        when :vcall
          check_bare_name(node[1], nil, path)
        when :fcall
          check_bare_name(node[1], nil, path)
        when :command
          check_bare_name(node[1], node[2], path)
        when :method_add_arg
          inner = node[1]
          args = node[2]
          case inner[0]
          when :fcall
            check_bare_name(inner[1], args, path)
          when :call
            check_receiver_call(inner, path)
            visit(args, path)
          else
            fail!(path, line_of(inner), "unsupported call form")
          end
        when :method_add_block
          visit(node[1], path)
          visit(node[2], path)
        when :call
          check_receiver_call(node, path)
        when :command_call
          check_receiver_call(node, path)
          visit(node[4], path)
        when :do_block, :brace_block
          fail!(path, line_of(node), "blocks may not take parameters") unless node[1].nil?
          visit(node[2], path)
        else
          fail!(path, line_of(node), "the construct #{node[0]} is not allowed in a contract file")
        end
      end

      def visit_assocs(list, path)
        return if list.nil?
        list.each { |assoc| visit(assoc, path) }
      end

      def visit_var_ref(inner, path)
        unless inner.is_a?(::Array)
          fail!(path, nil, "unsupported reference")
          return
        end
        case inner[0]
        when :@kw
          unless KEYWORD_LITERALS.include?(inner[1])
            fail!(path, inner[2][0], "the keyword '#{inner[1]}' is not allowed in a contract file")
          end
        when :@const
          name = inner[1]
          unless SCALARS.include?(name) || name == "Dovetail"
            fail!(path, inner[2][0], "the constant #{name} is not allowed in a contract file")
          end
        when :@ident
          fail!(path, inner[2][0], "variables are not allowed in a contract file")
        else
          fail!(path, line_of(inner), "unsupported reference")
        end
      end

      def check_bare_name(ident_node, args_node, path)
        unless ident_node.is_a?(::Array) && ident_node[0] == :@ident
          fail!(path, line_of(ident_node), "unsupported call")
          return
        end
        name = ident_node[1]
        if name == "require"
          check_require_args(args_node, path)
        elsif DSL_NAMES.include?(name)
          visit(args_node, path)
        else
          fail!(path, ident_node[2][0], "the method '#{name}' is not allowed in a contract file")
        end
      end

      def check_receiver_call(node, path)
        receiver = node[1]
        period = node[2]
        method_ident = node[3]
        unless period.is_a?(::Array) && period[0] == :@period
          fail!(path, line_of(node), "unsupported call form")
        end
        unless receiver.is_a?(::Array) && receiver[0] == :var_ref &&
               receiver[1].is_a?(::Array) && receiver[1][0] == :@const && receiver[1][1] == "Dovetail"
          fail!(path, line_of(node), "method calls may only be made on Dovetail")
        end
        unless method_ident.is_a?(::Array) && method_ident[0] == :@ident && method_ident[1] == "contract"
          fail!(path, line_of(node), "Dovetail only accepts the contract method")
        end
      end

      def check_require_args(args_node, path)
        inner = args_node
        inner = inner[1] if inner.is_a?(::Array) && inner[0] == :arg_paren
        unless inner.is_a?(::Array) && inner[0] == :args_add_block
          fail!(path, line_of(args_node), "require needs exactly one string argument")
          return
        end
        list = inner[1]
        unless list.is_a?(::Array) && list.length == 1
          fail!(path, line_of(args_node), "require needs exactly one string argument")
          return
        end
        arg = list[0]
        unless arg.is_a?(::Array) && arg[0] == :string_literal
          fail!(path, line_of(arg), "require needs a plain string argument")
          return
        end
        text = plain_string(arg, path)
        unless text == "dovetail"
          fail!(path, line_of(arg), "require accepts only \"dovetail\"")
        end
      end

      def plain_string(node, path)
        content = node[1]
        parts = content.is_a?(::Array) ? content[1..-1] : []
        (parts || []).compact.map do |part|
          if part.is_a?(::Array) && part[0] == :@tstring_content
            part[1]
          else
            fail!(path, line_of(part), "string interpolation is not allowed in a contract file")
          end
        end.join
      end
    end
  end
end
