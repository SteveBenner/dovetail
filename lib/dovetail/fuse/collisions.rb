module Dovetail
  class Fuse
    module Collisions
      module_function

      def segments(route)
        route.split("/").reject { |s| s.empty? }
      end

      def routes_overlap?(a, b)
        sa = segments(a)
        sb = segments(b)
        return false if sa.length != sb.length
        sa.zip(sb).all? do |x, y|
          x == y || x.start_with?(":") || y.start_with?(":")
        end
      end

      def route_collisions(panel_shapes)
        findings = []
        modules = panel_shapes.keys
        modules.each_with_index do |mod_a, i|
          modules[(i + 1)..-1].each do |mod_b|
            panel_shapes[mod_a]["routes"].each do |ra|
              panel_shapes[mod_b]["routes"].each do |rb|
                if routes_overlap?(ra, rb)
                  findings << { "panels" => [mod_a, mod_b], "route_a" => ra, "route_b" => rb }
                end
              end
            end
          end
        end
        findings
      end

      def shortcut_collisions(panel_shapes)
        findings = []
        modules = panel_shapes.keys
        modules.each_with_index do |mod_a, i|
          modules[(i + 1)..-1].each do |mod_b|
            (panel_shapes[mod_a]["shortcuts"] || []).each do |sa|
              (panel_shapes[mod_b]["shortcuts"] || []).each do |sb|
                next unless sa["keys"] == sb["keys"]
                next if sa["scope"] == "view" && sb["scope"] == "view"
                findings << { "panels" => [mod_a, mod_b], "keys" => sa["keys"] }
              end
            end
          end
        end
        findings
      end

      def overlay_collisions(panel_shapes)
        findings = []
        seen = {}
        panel_shapes.each do |mod, shape|
          (shape["overlays"] || []).each do |o|
            name = o["name"]
            if seen[name]
              findings << { "panels" => [seen[name], mod], "overlay" => name }
            else
              seen[name] = mod
            end
          end
        end
        findings
      end

      def storage_key_collisions(panel_shapes)
        findings = []
        seen = {}
        panel_shapes.each do |mod, shape|
          (shape["storage_keys"] || []).each do |k|
            qualified = "#{mod}:#{k["name"]}"
            if seen[qualified]
              findings << { "panels" => [mod], "key" => qualified }
            else
              seen[qualified] = mod
            end
          end
        end
        findings
      end

      def event_findings(panel_shapes, all_emitters = nil)
        findings = []
        emitters = all_emitters || {}
        if all_emitters.nil?
          panel_shapes.each do |mod, shape|
            (shape["events"]["emits"] || []).each { |e| emitters[e] = mod }
          end
        end
        panel_shapes.each do |mod, shape|
          (shape["events"]["consumes"] || []).each do |event|
            unless emitters.key?(event)
              findings << { "consumer" => mod, "event" => event, "reason" => "producer does not emit this event" }
            end
          end
        end
        findings
      end
    end
  end
end
