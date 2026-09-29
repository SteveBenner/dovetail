require "set"

module Dovetail
  module Compiler
    module Typescript
      module_function

      SCALAR_TS = {
        "String" => "string", "Integer" => "number", "Decimal" => "Decimal", "Percent" => "Decimal",
        "Boolean" => "boolean", "Date" => "IsoDate", "DateTime" => "IsoDateTime", "Id" => "Id",
        "Money" => "Money", "Url" => "string", "Email" => "string"
      }.freeze

      RUNTIME_BRANDS = %w[Decimal IsoDate IsoDateTime Id CurrencyCode Money].freeze

      def generate(model, all_models)
        mod = model.module_id
        used_runtime = Set.new
        pascal_module = Title.pascal_case(mod)

        interfaces = []
        model.types.each do |name, type|
          interfaces << render_interface(Title.pascal_case(name), type["fields"], used_runtime)
        end

        op_type_names = {}
        model.operations.each do |name, op|
          op_type_names[name] = {
            "input" => resolve_and_maybe_render(op["input"], "#{Title.pascal_case(name)}Input", interfaces, used_runtime),
            "output" => resolve_and_maybe_render(op["output"], "#{Title.pascal_case(name)}Output", interfaces, used_runtime)
          }
        end

        event_type_names = {}
        model.emits.each do |name, event|
          event_type_names[name] = resolve_and_maybe_render(event["payload"], "#{Title.pascal_case(name)}Payload", interfaces, used_runtime)
        end

        cross_imports = {}
        consumed_type_names = {}
        model.consumes.each do |c|
          producer = all_models[c["module"]]
          if producer.nil?
            consumed_type_names[[c["module"], c["event"]]] = "unknown"
            next
          end
          event = producer.emits[c["event"]]
          if event.nil?
            consumed_type_names[[c["module"], c["event"]]] = "unknown"
            next
          end
          payload = event["payload"]
          if payload["kind"] == "inline"
            type_name = "#{Title.pascal_case(c["event"])}Payload"
          elsif payload["kind"] == "named"
            type_name = Title.pascal_case(payload["name"])
          else
            consumed_type_names[[c["module"], c["event"]]] = "unknown"
            next
          end
          (cross_imports[c["module"]] ||= Set.new) << type_name
          consumed_type_names[[c["module"], c["event"]]] = type_name
        end

        props_fields = model.panel ? model.panel["props"] : []
        props_name = "#{pascal_module}Props"
        if props_fields.nil? || props_fields.empty?
          props_decl = "export type #{props_name} = Record<string, never>;"
        else
          body = props_fields.map { |p|
            optional = !p["required"]
            "  readonly #{p["name"]}#{optional ? "?" : ""}: #{ts_type_expr(p["type"], used_runtime)};"
          }.join("\n")
          props_decl = "export interface #{props_name} {\n#{body}\n}"
        end

        emitted_ids = model.emits.keys.map { |e| "#{mod}.#{e}" }
        consumed_ids = model.consumes.map { |c| "#{c["module"]}.#{c["event"]}" }

        emitted_event_type = emitted_ids.empty? ? "never" : emitted_ids.map { |i| "'#{i}'" }.join(" | ")
        consumed_event_type = consumed_ids.empty? ? "never" : consumed_ids.map { |i| "'#{i}'" }.join(" | ")

        event_payloads_decl = if model.emits.empty?
          "export type #{pascal_module}EventPayloads = Record<string, never>;"
        else
          body = model.emits.keys.map { |e| "  readonly '#{mod}.#{e}': #{event_type_names[e]};" }.join("\n")
          "export interface #{pascal_module}EventPayloads {\n#{body}\n}"
        end

        event_union = if model.emits.empty?
          "export type #{pascal_module}Event = never;"
        else
          variants = model.emits.keys.map { |e| "{ readonly event: '#{mod}.#{e}'; readonly payload: #{event_type_names[e]} }" }
          "export type #{pascal_module}Event = #{variants.join(" | ")};"
        end

        overlays = model.panel ? model.panel["overlays"].map { |o| o["name"] } : []
        overlays_type = overlays.empty? ? "never" : overlays.map { |o| "'#{o}'" }.join(" | ")

        routes = model.panel ? model.panel["routes"] : []
        routes_type = routes.empty? ? "never" : routes.map { |r| "'#{r}'" }.join(" | ")

        storage_keys = model.panel ? model.panel["storage_keys"] : []
        storage_type = if storage_keys.empty?
          "Record<string, never>"
        else
          "{ " + storage_keys.map { |s| "#{s["name"]}: #{s["type"] ? ts_type_expr(s["type"], used_runtime) : "string"}" }.join("; ") + " }"
        end

        emits_map_type = if model.emits.empty?
          "Record<string, never>"
        else
          "{ " + model.emits.keys.map { |e| "'#{mod}.#{e}': #{event_type_names[e]}" }.join("; ") + " }"
        end

        consumes_map_type = if model.consumes.empty?
          "Record<string, never>"
        else
          "{ " + model.consumes.map { |c| "'#{c["module"]}.#{c["event"]}': #{consumed_type_names[[c["module"], c["event"]]]}" }.join("; ") + " }"
        end

        shortcuts = model.panel ? model.panel["shortcuts"].map { |s| s["keys"] } : []
        shortcuts_type = shortcuts.empty? ? "never" : shortcuts.map { |s| "'#{s}'" }.join(" | ")

        module_types_decl = <<~TS.rstrip
          export interface #{pascal_module}ModuleTypes {
            overlays: #{overlays_type};
            routes: #{routes_type};
            storage: #{storage_type};
            emits: #{emits_map_type};
            consumes: #{consumes_map_type};
            shortcuts: #{shortcuts_type};
            props: #{props_name};
          }
        TS

        import_lines = []
        runtime_names = RUNTIME_BRANDS.select { |n| used_runtime.include?(n) }
        import_lines << "import type { #{runtime_names.join(", ")} } from '@dovetail/runtime';" unless runtime_names.empty?
        cross_imports.each do |producer, names|
          import_lines << "import type { #{names.to_a.sort.join(", ")} } from './#{producer}';"
        end

        blocks = []
        blocks.concat(interfaces)
        blocks << props_decl
        blocks << "export type #{pascal_module}EmittedEvent = #{emitted_event_type};"
        blocks << event_payloads_decl
        blocks << "export type #{pascal_module}ConsumedEvent = #{consumed_event_type};"
        blocks << event_union
        blocks << module_types_decl

        [import_lines.join("\n"), blocks.join("\n\n")].reject(&:empty?).join("\n\n") + "\n"
      end

      def resolve_and_maybe_render(type_ref, synthesized_name, interfaces, used_runtime)
        if type_ref["kind"] == "inline"
          interfaces << render_interface(synthesized_name, type_ref["fields"], used_runtime)
          synthesized_name
        else
          ts_type_expr(type_ref, used_runtime)
        end
      end

      def ts_type_expr(type_ref, used_runtime, type_imports = nil)
        case type_ref["kind"]
        when "scalar"
          ts = SCALAR_TS.fetch(type_ref["name"], "unknown")
          used_runtime << ts if RUNTIME_BRANDS.include?(ts)
          ts
        when "named"
          name = Title.pascal_case(type_ref["name"])
          type_imports << name if type_imports
          name
        when "ref"
          "import('./#{type_ref["module"]}').#{Title.pascal_case(type_ref["name"])}"
        when "list"
          "readonly #{ts_type_expr(type_ref["of"], used_runtime, type_imports)}[]"
        when "map"
          "Readonly<Record<string, #{ts_type_expr(type_ref["of"], used_runtime, type_imports)}>>"
        when "one_of"
          type_ref["names"].each { |n| type_imports << Title.pascal_case(n) if type_imports }
          type_ref["names"].map { |n| "(#{Title.pascal_case(n)} & { readonly kind: '#{n}' })" }.join(" | ")
        when "inline"
          if type_ref["fields"].empty?
            "Record<string, never>"
          else
            "{ " + type_ref["fields"].map { |f| render_field_line(f, used_runtime) }.join(" ") + " }"
          end
        else
          "unknown"
        end
      end

      def render_field_line(f, used_runtime)
        optional = !f["required"] || f["has_default"]
        expr = ts_type_expr(f["type"], used_runtime)
        expr = "#{expr} | null" if f["nullable"]
        "readonly #{f["name"]}#{optional ? "?" : ""}: #{expr};"
      end

      def render_interface(name, fields, used_runtime)
        if fields.empty?
          "export type #{name} = Record<string, never>;"
        else
          body = fields.map { |f| "  " + render_field_line(f, used_runtime) }.join("\n")
          "export interface #{name} {\n#{body}\n}"
        end
      end
    end
  end
end
