module Dovetail
  module Contract
    module Validator
      module_function

      def validate(models)
        by_module = {}
        models.each { |m| by_module[m.module_id] = m }
        findings = []
        models.each do |model|
          findings.concat(check_c001(model, by_module))
          findings.concat(check_c002(model))
          findings.concat(check_c003(model, by_module))
          findings.concat(check_c004(model))
          findings.concat(check_c005(model))
          findings.concat(check_c006(model))
        end
        findings
      end

      def collect_refs(type_ref, out)
        return if type_ref.nil?
        out << type_ref
        case type_ref["kind"]
        when "list", "map"
          collect_refs(type_ref["of"], out)
        when "inline"
          type_ref["fields"].each { |f| collect_refs(f["type"], out) }
        end
      end

      def check_c001(model, by_module)
        findings = []
        refs = []
        model.types.each_value { |t| t["fields"].each { |f| collect_refs(f["type"], refs) } }
        model.operations.each_value { |op| collect_refs(op["input"], refs); collect_refs(op["output"], refs) }
        model.emits.each_value { |e| collect_refs(e["payload"], refs) }
        panel = model.panel
        if panel
          panel["props"].each { |p| collect_refs(p["type"], refs) }
          panel["storage_keys"].each { |s| collect_refs(s["type"], refs) if s["type"] }
        end
        refs.each do |ref|
          case ref["kind"]
          when "named"
            unless model.types.key?(ref["name"])
              findings << Finding.new("C001", "error", model.module_id, "references unknown type '#{ref["name"]}'")
            end
          when "one_of"
            ref["names"].each do |n|
              unless model.types.key?(n)
                findings << Finding.new("C001", "error", model.module_id, "references unknown type '#{n}' in one_of")
              end
            end
          when "ref"
            target = by_module[ref["module"]]
            if target.nil?
              findings << Finding.new("C001", "warning", model.module_id, "refers to module '#{ref["module"]}' which is not in the compiled set")
            elsif !target.types.key?(ref["name"])
              findings << Finding.new("C001", "error", model.module_id, "references unknown type '#{ref["module"]}.#{ref["name"]}'")
            end
          end
        end
        findings
      end

      def check_c002(model)
        findings = []
        (model.duplicates || {}).each do |category, names|
          names.each do |n|
            findings << Finding.new("C002", "error", model.module_id, "duplicate #{category} name '#{n}'")
          end
        end
        model.types.each_key do |name|
          if ScalarMarker::SCALARS.map(&:downcase).include?(name.downcase)
            findings << Finding.new("C002", "error", model.module_id, "type name '#{name}' shadows a scalar type")
          end
        end
        findings
      end

      def check_c003(model, by_module)
        findings = []
        model.consumes.each do |c|
          target = by_module[c["module"]]
          if target.nil?
            findings << Finding.new("C003", "warning", model.module_id, "consumes '#{c["module"]}.#{c["event"]}' but module '#{c["module"]}' is not in the compiled set")
            next
          end
          unless target.emits.key?(c["event"])
            findings << Finding.new("C003", "error", model.module_id, "consumes '#{c["module"]}.#{c["event"]}' which that module does not emit")
          end
          dep = model.depends_on.find { |d| d["module"] == c["module"] }
          if dep && !requirement_satisfied?(dep["requirement"], target.version)
            findings << Finding.new("C003", "error", model.module_id, "requires #{c["module"]} #{dep["requirement"]} but found version #{target.version}")
          end
        end
        findings
      end

      def requirement_satisfied?(req, actual)
        match = req.to_s.match(/\A(>=|<=|~>|>|<|=)\s*(\d+)\z/)
        return true unless match
        op = match[1]
        n = match[2].to_i
        case op
        when ">=" then actual >= n
        when ">" then actual > n
        when "<=" then actual <= n
        when "<" then actual < n
        when "=" then actual == n
        when "~>" then actual >= n
        else true
        end
      end

      def check_c004(model)
        findings = []
        panel = model.panel
        return findings unless panel
        required = %w[loading empty error unavailable ready]
        panel["views"].each do |v|
          unless model.operations.key?(v["data"])
            findings << Finding.new("C004", "error", model.module_id, "view '#{v["name"]}' uses unknown operation '#{v["data"]}'")
          end
          missing = required - v["states"]
          unless missing.empty?
            findings << Finding.new("C004", "error", model.module_id, "view '#{v["name"]}' is missing states #{missing.join(", ")}")
          end
        end
        findings
      end

      def check_c005(model)
        findings = []
        panel = model.panel
        return findings unless panel
        namespace = "/" + model.module_id.tr("_", "-")
        routes = panel["routes"]
        routes.each do |r|
          unless r == namespace || r.start_with?("#{namespace}/")
            findings << Finding.new("C005", "error", model.module_id, "route '#{r}' is outside the module's namespace '#{namespace}'")
          end
        end
        routes.combination(2).each do |a, b|
          if routes_collide?(a, b)
            findings << Finding.new("C005", "error", model.module_id, "routes '#{a}' and '#{b}' can match the same path")
          end
        end
        findings
      end

      def routes_collide?(a, b)
        sa = a.split("/")
        sb = b.split("/")
        return false if sa.length != sb.length
        sa.zip(sb).all? { |x, y| x == y || x.start_with?(":") || y.start_with?(":") }
      end

      def check_c006(model)
        findings = []
        panel = model.panel
        return findings unless panel
        caps = panel["capabilities"]
        if !panel["storage_keys"].empty? && !caps.include?("storage")
          findings << Finding.new("C006", "error", model.module_id, "uses storage_key without capability :storage")
        end
        if !panel["shortcuts"].empty? && !caps.include?("keyboard")
          findings << Finding.new("C006", "error", model.module_id, "uses shortcut without capability :keyboard")
        end
        if !panel["overlays"].empty? && !caps.include?("overlay")
          findings << Finding.new("C006", "error", model.module_id, "uses overlay without capability :overlay")
        end
        namespace = "/" + model.module_id.tr("_", "-")
        extra_routes = panel["routes"].reject { |r| r == namespace }
        if !extra_routes.empty? && !caps.include?("navigation")
          findings << Finding.new("C006", "error", model.module_id, "declares routes beyond the namespace without capability :navigation")
        end
        findings
      end
    end
  end
end
