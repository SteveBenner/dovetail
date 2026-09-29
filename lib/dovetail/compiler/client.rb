require "set"

module Dovetail
  module Compiler
    module Client
      module_function

      def generate(model)
        mod = model.module_id
        type_imports = Set.new
        runtime_imports = Set.new

        entries = model.operations.sort.map do |name, op|
          input_expr = type_expr_for(op["input"], "#{Title.pascal_case(name)}Input", type_imports, runtime_imports)
          output_expr = type_expr_for(op["output"], "#{Title.pascal_case(name)}Output", type_imports, runtime_imports)
          errors = (op["errors"] + ["CommonErrorCode"]).map { |e| e == "CommonErrorCode" ? e : "'#{e}'" }.join(" | ")
          no_input = op["input"]["kind"] == "inline" && op["input"]["fields"].empty?
          if no_input
            params = ""
            call_arg = "{}"
          else
            params = "input: #{input_expr}"
            call_arg = "input"
          end
          signature = "#{name}(#{params}): Promise<Result<#{output_expr}, #{errors}>> {"
          body = "    return callOperation('#{mod}', '#{name}', #{call_arg}, { timeout_ms: #{op["timeout_ms"]}, idempotent: #{op["idempotent"]}, contract_version: #{model.version} });"
          [signature, body, "  },"].join("\n")
        end

        runtime_line_names = (["callOperation"] + ["type Result", "type CommonErrorCode"] + runtime_imports.to_a.sort.map { |n| "type #{n}" }).uniq
        lines = []
        lines << "import { #{runtime_line_names.join(", ")} } from '@dovetail/runtime';"
        unless type_imports.empty?
          lines << "import type { #{type_imports.to_a.sort.join(", ")} } from '../types/#{mod}';"
        end
        lines << ""
        camel = Title.camel_case(mod)
        lines << "export const #{camel} = {"
        entries.each { |e| lines << "  #{e}" }
        lines << "} as const;"
        lines << ""
        lines << "export default #{camel};"
        lines.join("\n") + "\n"
      end

      def type_expr_for(type_ref, synthesized_name, type_imports, runtime_imports)
        case type_ref["kind"]
        when "inline"
          if type_ref["fields"].empty?
            "Record<string, never>"
          else
            type_imports << synthesized_name
            synthesized_name
          end
        when "named"
          name = Title.pascal_case(type_ref["name"])
          type_imports << name
          name
        else
          Typescript.ts_type_expr(type_ref, runtime_imports, type_imports)
        end
      end
    end
  end
end
