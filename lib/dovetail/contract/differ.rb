module Dovetail
  module Contract
    module Differ
      module_function

      def diff(old_hash, new_hash)
        changes = []
        diff_types(old_hash["types"] || {}, new_hash["types"] || {}, changes)
        diff_operations(old_hash["operations"] || {}, new_hash["operations"] || {}, changes)
        diff_emits(old_hash["emits"] || {}, new_hash["emits"] || {}, changes)
        diff_panel(old_hash["panel"], new_hash["panel"], changes)
        changes
      end

      def version_ok?(old_hash, new_hash, changes)
        return true if old_hash["version"] != new_hash["version"]
        changes.none? { |c| c.kind == :breaking }
      end

      def diff_types(old_types, new_types, changes)
        old_types.each_key do |name|
          unless new_types.key?(name)
            changes << Change.new(:breaking, "removed type '#{name}'")
            next
          end
          diff_fields(name, old_types[name]["fields"], new_types[name]["fields"], changes)
        end
        new_types.each_key do |name|
          changes << Change.new(:compatible, "added type '#{name}'") unless old_types.key?(name)
        end
      end

      def diff_fields(type_name, old_fields, new_fields, changes)
        old_by_name = old_fields.each_with_object({}) { |f, h| h[f["name"]] = f }
        new_by_name = new_fields.each_with_object({}) { |f, h| h[f["name"]] = f }
        old_by_name.each do |name, old_field|
          new_field = new_by_name[name]
          if new_field.nil?
            changes << Change.new(:breaking, "removed field '#{type_name}.#{name}'")
            next
          end
          if old_field["type"] != new_field["type"]
            changes << Change.new(:breaking, "changed type of field '#{type_name}.#{name}'")
          end
          if !old_field["required"] && new_field["required"]
            changes << Change.new(:breaking, "field '#{type_name}.#{name}' is now required")
          elsif old_field["required"] && !new_field["required"]
            changes << Change.new(:compatible, "field '#{type_name}.#{name}' is now optional")
          end
          diff_enum(type_name, name, old_field["enum"], new_field["enum"], changes)
          diff_range(type_name, name, old_field, new_field, changes)
        end
        new_by_name.each do |name, new_field|
          next if old_by_name.key?(name)
          if new_field["required"] && !new_field["has_default"]
            changes << Change.new(:breaking, "added required field '#{type_name}.#{name}' with no default")
          else
            changes << Change.new(:compatible, "added field '#{type_name}.#{name}'")
          end
        end
      end

      def diff_enum(type_name, field_name, old_enum, new_enum, changes)
        return if old_enum.nil? && new_enum.nil?
        old_set = (old_enum || [])
        new_set = (new_enum || [])
        removed = old_set - new_set
        added = new_set - old_set
        changes << Change.new(:breaking, "narrowed enum on '#{type_name}.#{field_name}'") unless removed.empty?
        changes << Change.new(:compatible, "widened enum on '#{type_name}.#{field_name}'") unless added.empty?
      end

      def diff_range(type_name, field_name, old_field, new_field, changes)
        old_min = old_field["min"]
        new_min = new_field["min"]
        old_max = old_field["max"]
        new_max = new_field["max"]
        if new_min && (old_min.nil? || new_min > old_min)
          changes << Change.new(:breaking, "narrowed minimum on '#{type_name}.#{field_name}'")
        elsif old_min && (new_min.nil? || new_min < old_min)
          changes << Change.new(:compatible, "widened minimum on '#{type_name}.#{field_name}'")
        end
        if new_max && (old_max.nil? || new_max < old_max)
          changes << Change.new(:breaking, "narrowed maximum on '#{type_name}.#{field_name}'")
        elsif old_max && (new_max.nil? || new_max > old_max)
          changes << Change.new(:compatible, "widened maximum on '#{type_name}.#{field_name}'")
        end
      end

      def diff_type_ref(label, old_ref, new_ref, changes)
        if old_ref && new_ref && old_ref["kind"] == "inline" && new_ref["kind"] == "inline"
          diff_fields(label, old_ref["fields"], new_ref["fields"], changes)
        elsif old_ref != new_ref
          changes << Change.new(:breaking, "changed #{label}")
        end
      end

      def diff_operations(old_ops, new_ops, changes)
        old_ops.each_key do |name|
          new_op = new_ops[name]
          if new_op.nil?
            changes << Change.new(:breaking, "removed operation '#{name}'")
            next
          end
          old_op = old_ops[name]
          diff_type_ref("input of operation '#{name}'", old_op["input"], new_op["input"], changes)
          diff_type_ref("output of operation '#{name}'", old_op["output"], new_op["output"], changes)
        end
        new_ops.each_key do |name|
          changes << Change.new(:compatible, "added operation '#{name}'") unless old_ops.key?(name)
        end
      end

      def diff_emits(old_emits, new_emits, changes)
        old_emits.each_key do |name|
          new_event = new_emits[name]
          if new_event.nil?
            changes << Change.new(:breaking, "removed event '#{name}'")
            next
          end
          diff_type_ref("payload of event '#{name}'", old_emits[name]["payload"], new_event["payload"], changes)
        end
        new_emits.each_key do |name|
          changes << Change.new(:compatible, "added event '#{name}'") unless old_emits.key?(name)
        end
      end

      def diff_panel(old_panel, new_panel, changes)
        return if old_panel.nil? && new_panel.nil?
        if old_panel.nil?
          changes << Change.new(:compatible, "added a panel")
          return
        end
        if new_panel.nil?
          changes << Change.new(:breaking, "removed the panel")
          return
        end
        diff_named_list(old_panel["slots"], new_panel["slots"], "slot", changes)
        diff_route_list(old_panel["routes"], new_panel["routes"], changes)
        diff_views(old_panel["views"], new_panel["views"], changes)
      end

      def diff_named_list(old_list, new_list, label, changes)
        old_names = old_list.map { |i| i["name"] }
        new_names = new_list.map { |i| i["name"] }
        (old_names - new_names).each { |n| changes << Change.new(:breaking, "removed #{label} '#{n}'") }
        (new_names - old_names).each { |n| changes << Change.new(:compatible, "added #{label} '#{n}'") }
      end

      def diff_route_list(old_routes, new_routes, changes)
        (old_routes - new_routes).each { |r| changes << Change.new(:breaking, "removed route '#{r}'") }
        (new_routes - old_routes).each { |r| changes << Change.new(:compatible, "added route '#{r}'") }
      end

      def diff_views(old_views, new_views, changes)
        old_by_name = old_views.each_with_object({}) { |v, h| h[v["name"]] = v }
        new_by_name = new_views.each_with_object({}) { |v, h| h[v["name"]] = v }
        required = %w[loading empty error unavailable ready]
        old_by_name.each do |name, old_view|
          new_view = new_by_name[name]
          next if new_view.nil?
          extra_added = (new_view["states"] - required) - (old_view["states"] - required)
          extra_added.each { |_| changes << Change.new(:compatible, "added a state to view '#{name}'") }
        end
      end
    end
  end
end
