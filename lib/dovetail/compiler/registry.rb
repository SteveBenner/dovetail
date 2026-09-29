module Dovetail
  module Compiler
    module Registry
      module_function

      def generate(model)
        panel = model.panel
        return nil unless panel
        mod = model.module_id
        schema_file = "schema/#{mod}.schema.json"
        ref_base = "#{mod}.schema.json"
        {
          "schema" => "dovetail.registry-entry/v1",
          "module" => mod,
          "title" => Title.for_module(mod),
          "contract_version" => model.version,
          "schema_file" => schema_file,
          "slots" => panel["slots"].map { |s| { "name" => s["name"], "size" => s["size"], "min_width" => s["min_width"], "max_width" => s["max_width"] } },
          "routes" => panel["routes"],
          "overlays" => panel["overlays"].map { |o| { "name" => o["name"], "kind" => o["kind"], "dismissible" => o["dismissible"], "blocking" => o["blocking"] } },
          "shortcuts" => panel["shortcuts"],
          "storage_keys" => panel["storage_keys"].map { |s| { "name" => s["name"], "ttl_days" => s["ttl_days"], "schema" => { "$ref" => "#{ref_base}#/$defs/storage.#{s["name"]}" } } },
          "emits" => model.emits.keys.map { |e| { "id" => "#{mod}.#{e}", "payload_schema" => { "$ref" => "#{ref_base}#/$defs/event.#{e}.payload" } } },
          "consumes" => model.consumes.map { |c| "#{c["module"]}.#{c["event"]}" },
          "operations" => model.operations.map { |name, op|
            {
              "id" => "#{mod}.#{name}",
              "name" => name,
              "timeout_ms" => op["timeout_ms"],
              "idempotent" => op["idempotent"],
              "errors" => op["errors"],
              "input_schema" => { "$ref" => "#{ref_base}#/$defs/operation.#{name}.input" },
              "output_schema" => { "$ref" => "#{ref_base}#/$defs/operation.#{name}.output" }
            }
          },
          "prefetch" => prefetch_operations(model, panel),
          "views" => panel["views"].map { |v| { "name" => v["name"], "data_operation" => "#{mod}.#{v["data"]}", "states" => v["states"] } },
          "props" => panel["props"].map { |p| { "name" => p["name"], "required" => p["required"], "schema" => { "$ref" => "#{ref_base}#/$defs/prop.#{p["name"]}" } } },
          "depends_on" => model.depends_on
        }
      end

      def prefetch_operations(model, panel)
        panel["views"].map { |v| v["data"] }.uniq.select do |name|
          op = model.operations[name]
          op && op["idempotent"] == true && op["input"] == { "kind" => "inline", "fields" => [] }
        end.sort
      end
    end
  end
end
