module Dovetail
  class Fuse
    module Prefetch
      module_function

      def manifest(entries, layout)
        home = layout.home || (layout.navigation.first || {})["module"] || (entries.first || {})["module"]
        owners = { "/" => home }
        entries.each do |entry|
          (entry["routes"] || []).each { |r| owners[r] = entry["module"] }
        end
        routes = {}
        owners.keys.sort.each do |route|
          owner = owners[route]
          ops = []
          entries.each do |panel|
            next unless placed?(panel, owner, home, layout)
            (panel["prefetch"] || []).each { |op| ops << "#{panel["module"]}.#{op}" }
          end
          routes[route] = ops.uniq.sort
        end
        { "schema" => "dovetail.prefetch/v1", "home" => home, "routes" => routes }
      end

      def placed?(panel, owner, home, layout)
        (panel["slots"] || []).any? do |slot|
          target = layout.slots.find { |s| s["name"] == slot["name"] } || layout.slots.find { |s| s["size"] == slot["size"] }
          target && active?(target, panel["module"], owner, home)
        end
      end

      def active?(target, panel_module, owner, home)
        return true if target["region"] == "dock"
        case target["size"]
        when "main", "full", "aside"
          panel_module == owner
        when "tile"
          owner == home
        else
          true
        end
      end
    end
  end
end
