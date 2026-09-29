module Dovetail
  module Compiler
    module Shape
      module_function

      def generate(model)
        panel = model.panel
        return nil unless panel
        mod = model.module_id
        {
          "schema" => "dovetail.shape/v1",
          "module" => mod,
          "contract_version" => model.version,
          "slots" => panel["slots"].map { |s| { "name" => s["name"], "size" => s["size"], "min_width" => s["min_width"], "max_width" => s["max_width"] } },
          "views" => panel["views"].map { |v| { "name" => v["name"], "data_operation" => "#{mod}.#{v["data"]}", "states" => v["states"] } },
          "capabilities" => panel["capabilities"].sort,
          "overlays" => panel["overlays"].map { |o| { "name" => o["name"], "kind" => o["kind"], "dismissible" => o["dismissible"], "blocking" => o["blocking"] } },
          "routes" => panel["routes"],
          "events" => {
            "emits" => model.emits.keys.map { |e| "#{mod}.#{e}" }.sort,
            "consumes" => model.consumes.map { |c| "#{c["module"]}.#{c["event"]}" }.sort
          },
          "operations" => model.operations.keys.map { |o| "#{mod}.#{o}" }.sort,
          "storage_keys" => panel["storage_keys"].map { |s| { "name" => s["name"], "ttl_days" => s["ttl_days"] } },
          "shortcuts" => panel["shortcuts"],
          "tokens" => panel["tokens"],
          "rules_profile" => "strict"
        }
      end
    end
  end
end
