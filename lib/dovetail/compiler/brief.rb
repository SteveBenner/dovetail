require "yaml"

module Dovetail
  module Compiler
    module Brief
      module_function

      RULE_BY_CAPABILITY = {
        "overlay" => "S-OVL-001",
        "navigation" => "S-NAV-001",
        "storage" => "S-STO-001",
        "keyboard" => "S-KEY-001"
      }.freeze

      FALLBACK_EXAMPLES = {
        "S-OVL-001" => "<button onclick={() => openOverlay('finding_detail', FindingDetail, { id })}>Details</button>",
        "S-NAV-001" => "navigate('/finance/findings/:id', { id });",
        "S-STO-001" => "store('filters').set(filters);",
        "S-KEY-001" => "shortcut('mod+k', openSearch);"
      }.freeze

      MISSING_BULLETS = {
        "overlay" => "- No overlays. Your contract declares none, so no modals, drawers, popovers, menus or toasts.",
        "navigation" => "- No navigation. Your contract declares no routes to move between, so no navigate or link calls.",
        "storage" => "- No saved settings. Your contract declares no storage keys, so nothing is kept in the browser.",
        "keyboard" => "- No keyboard shortcuts. Your contract declares none."
      }.freeze

      RESTRICTABLE = %w[overlay navigation storage keyboard].freeze

      SLOT_PHRASES = {
        "aside" => "the side column, 280 to 400 px wide",
        "tile" => "a tile in the dashboard grid",
        "strip" => "a full-width band up to 160 px tall",
        "full" => "the whole content area"
      }.freeze

      FREE_TEXT = "Everything else inside your slots is yours to design: layout, wording, charts, your own components and motion within the theme's tokens.".freeze

      NEVER_REACH_PAST_SLOT = "- Never reach past your slot directly: no fetch, no localStorage, no window or document listeners, no document.querySelector or appending to the page, no fixed positioning and no z-index. dovetail check names the primitive to use instead.".freeze

      ALWAYS_AVAILABLE = "Always available: the generated client for your operations, the events you declared, every, after and frame for timing, and useId for ids.".freeze

      def rules_by_id
        return @rules_by_id if @rules_by_id
        path = File.join(Dovetail.root, "lib", "dovetail", "shape", "rules.yml")
        data = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
        @rules_by_id = (data["rules"] || []).each_with_object({}) { |r, h| h[r["id"]] = r }
      rescue StandardError
        @rules_by_id = {}
      end

      def example_compliant_for_rule(rule_id)
        rule = rules_by_id[rule_id]
        (rule && rule["example_compliant"]) || FALLBACK_EXAMPLES.fetch(rule_id, "")
      end

      def render(model, models = {})
        panel = model.panel
        title = Title.for_module(model.module_id)
        description = model.to_h["description"]
        slots = panel ? panel["slots"] : []
        views = (panel ? panel["views"] : []).map { |v| { name: v["name"], qualified_op: "#{model.module_id}.#{v["data"]}" } }
        sensitive_names = sensitive_fields_for_model(model)
        capabilities = panel ? panel["capabilities"] : []
        overlays = panel ? panel["overlays"] : []
        routes = panel ? panel["routes"] : []
        storage_keys = panel ? panel["storage_keys"] : []
        shortcuts = panel ? panel["shortcuts"] : []
        tokens = panel ? panel["tokens"] : []
        sends = model.emits.map { |name, e| { id: "#{model.module_id}.#{name}", fields: resolve_fields(e["payload"], model).map { |f| f["name"] } } }
        hears = model.consumes.map { |c| { id: "#{c["module"]}.#{c["event"]}", fields: heard_event_fields(c, models) } }

        assemble(
          title,
          what_its_for_model(title, description),
          where_it_renders(slots),
          what_data(views, sensitive_names),
          may_do(capabilities, overlays, routes, storage_keys, shortcuts),
          may_not_do(capabilities),
          events_section(sends, hears),
          tokens_section(tokens)
        )
      end

      def render_shape(shape)
        title = Title.for_module(shape["module"])
        slots = shape["slots"]
        views = (shape["views"] || []).map { |v| { name: v["name"], qualified_op: v["data_operation"] } }
        capabilities = shape["capabilities"]
        overlays = shape["overlays"]
        routes = shape["routes"]
        storage_keys = shape["storage_keys"]
        shortcuts = shape["shortcuts"]
        tokens = shape["tokens"]
        sends = (shape["events"]["emits"] || []).map { |id| { id: id, fields: nil } }
        hears = (shape["events"]["consumes"] || []).map { |id| { id: id, fields: nil } }

        assemble(
          title,
          what_its_for_shape(title),
          where_it_renders(slots),
          what_data(views, []),
          may_do(capabilities, overlays, routes, storage_keys, shortcuts),
          may_not_do(capabilities),
          events_section(sends, hears),
          tokens_section(tokens)
        )
      end

      def assemble(title, for_body, renders_body, data_body, may_do_body, may_not_do_body, events_body, tokens_body)
        lines = []
        lines << "# #{title} panel brief"
        lines << ""
        lines << "## What your panel is for"
        lines << ""
        lines << for_body
        lines << ""
        lines << "## Where it renders"
        lines << ""
        lines << renders_body
        lines << ""
        lines << "## What data it shows"
        lines << ""
        lines << data_body
        lines << ""
        lines << "## What it may do across its edge"
        lines << ""
        lines << may_do_body
        lines << ""
        lines << "## What it may not do"
        lines << ""
        lines << may_not_do_body
        lines << ""
        lines << "## Events it sends and receives"
        lines << ""
        lines << events_body
        lines << ""
        lines << "## Tokens it may style with"
        lines << ""
        lines << tokens_body
        lines << ""
        lines << "## What is completely free"
        lines << ""
        lines << FREE_TEXT
        lines << ""
        lines.join("\n")
      end

      def what_its_for_model(title, description)
        description || "Your #{title} panel is one part of the application. Its contract does not describe it yet."
      end

      def what_its_for_shape(title)
        base = "Your #{title} panel is one part of the application. Its contract does not describe it yet."
        "#{base} This brief was made from the shape alone, so it leaves out descriptions and event fields."
      end

      def where_it_renders(slots)
        bullets = (slots || []).map { |s| "- #{s["name"]}: #{slot_phrase(s)}" }
        tail = "Start your headings at h2 in the main area and at h3 everywhere else."
        bullets.empty? ? tail : "#{bullets.join("\n")}\n\n#{tail}"
      end

      def slot_phrase(slot)
        if slot["size"] == "main"
          slot["min_width"] ? "the main area, at least #{slot["min_width"]} px wide" : "the main area"
        else
          SLOT_PHRASES.fetch(slot["size"], slot["size"])
        end
      end

      def what_data(views, sensitive_names)
        lines = []
        if views.nil? || views.empty?
          lines << "It shows no data views."
        else
          lines << (views.length == 1 ? "It has one data view." : "It has #{views.length} data views.")
          views.each do |v|
            lines << "- #{v[:name]}, from #{v[:qualified_op]}(): show loading, empty, error, unavailable and ready."
          end
        end
        sensitive_names.each do |name|
          lines << "- #{name} is sensitive. Show only what the view needs and never copy it into messages or storage."
        end
        lines.join("\n")
      end

      def resolve_fields(type_ref, model)
        return [] if type_ref.nil?
        case type_ref["kind"]
        when "inline"
          type_ref["fields"]
        when "named"
          (model.types[type_ref["name"]] || {})["fields"] || []
        when "list", "map"
          resolve_fields(type_ref["of"], model)
        when "one_of"
          type_ref["names"].flat_map { |n| (model.types[n] || {})["fields"] || [] }
        else
          []
        end
      end

      def heard_event_fields(consumed, models)
        producer = models[consumed["module"]]
        return nil unless producer
        event = producer.emits[consumed["event"]]
        return nil unless event
        resolve_fields(event["payload"], producer).map { |f| f["name"] }
      end

      def sensitive_fields_for_model(model)
        panel = model.panel
        return [] unless panel
        names = []
        panel["views"].each do |v|
          op = model.operations[v["data"]]
          next unless op
          resolve_fields(op["output"], model).each do |f|
            names << f["name"] if f["sensitive"] && !names.include?(f["name"])
          end
        end
        names
      end

      def may_do(capabilities, overlays, routes, storage_keys, shortcuts)
        lines = [ALWAYS_AVAILABLE]
        (capabilities || []).sort.each do |cap|
          lines << may_do_bullet(cap, overlays, routes, storage_keys, shortcuts)
        end
        lines.join("\n")
      end

      def may_do_bullet(cap, overlays, routes, storage_keys, shortcuts)
        case cap
        when "overlay"
          name = overlays && overlays[0] && overlays[0]["name"]
          name ? "- Overlays, through openOverlay or <Overlay>: openOverlay('#{name}', Component, {})" : "- Overlays, through openOverlay or <Overlay>: #{example_compliant_for_rule("S-OVL-001")}"
        when "navigation"
          route = navigation_route(routes)
          route ? "- Navigation, through navigate and link: navigate('#{route}'#{route_params_suffix(route)})" : "- Navigation, through navigate and link: #{example_compliant_for_rule("S-NAV-001")}"
        when "storage"
          name = storage_keys && storage_keys[0] && storage_keys[0]["name"]
          name ? "- Saved settings, through store: store('#{name}').set(value)" : "- Saved settings, through store: #{example_compliant_for_rule("S-STO-001")}"
        when "keyboard"
          keys = shortcuts && shortcuts[0] && shortcuts[0]["keys"]
          keys ? "- Keyboard shortcuts, through shortcut: shortcut('#{keys}', handler)" : "- Keyboard shortcuts, through shortcut: #{example_compliant_for_rule("S-KEY-001")}"
        when "lifecycle"
          "- Timers, through every: every(5000, refresh)"
        else
          "- #{cap[0].upcase}#{cap[1..-1]}."
        end
      end

      def navigation_route(routes)
        return nil if routes.nil? || routes.empty?
        routes.length > 1 ? routes[1] : routes[0]
      end

      def route_params_suffix(route)
        params = route.scan(/:([a-zA-Z_][a-zA-Z0-9_]*)/).map(&:first)
        return "" if params.empty?
        ", { #{params.join(", ")} }"
      end

      def may_not_do(capabilities)
        lines = (RESTRICTABLE - (capabilities || [])).map { |c| MISSING_BULLETS[c] }
        lines << NEVER_REACH_PAST_SLOT
        lines.join("\n")
      end

      def events_section(sends, hears)
        "#{events_lines("send", sends)}\n\n#{events_lines("hear", hears)}"
      end

      def events_lines(label, items)
        return "You #{label} no events." if items.nil? || items.empty?
        lines = ["You #{label}:"]
        items.each do |it|
          if it[:fields] && !it[:fields].empty?
            lines << "- #{it[:id]} with #{it[:fields].join(", ")}"
          else
            lines << "- #{it[:id]}"
          end
        end
        lines.join("\n")
      end

      def tokens_section(tokens)
        tokens = tokens || []
        base = "Use only the theme's token classes and var(--token) values, such as bg-surface-2, text-text-dim, p-4 and rounded-lg, so your panel looks right in every theme."
        if tokens == ["default"] || tokens.empty?
          base
        else
          "#{base} Your contract allows these families: #{tokens.join(", ")}."
        end
      end
    end
  end
end
