require "json"

module Dovetail
  class Verify
    class Journeys
      CRASH_MARKER = "Dovetail: forced crash"

      def initialize(page:, screenshots_dir:, base_url:, panel_entries: {}, exceptions: [])
        @page = page
        @screenshots_dir = screenshots_dir
        @base_url = base_url
        @panel_entries = panel_entries
        @exceptions = exceptions
        @shot_count = 0
      end

      def run_all
        failures = []
        panels = safe_eval("window.__dovetail.panels()") || []

        overlay_journey(panels, failures)
        stacked_overlay_journey(panels, failures)
        route_journey(panels, failures)
        event_journey(panels, failures)
        state_journey(panels, failures)
        leak_journey(panels, failures)
        slot_journey(panels, failures)
        crash_journey(panels, failures)
        axe_journey(panels, failures)
        global_journey(failures)

        { "ok" => failures.empty?, "journeys" => failures }
      end

      def run_embed(tag:, ready:, exceptions_from:)
        failures = []
        unless ready
          record(failures, "embed", tag, "the element never dispatched dovetail-ready")
          return { "ok" => false, "journeys" => failures }
        end
        selector = "document.querySelector('#{tag}').shadowRoot"
        mounted = safe_eval("Array.from(#{selector}.querySelectorAll('[data-dovetail-panel]')).map(function (el) { return el.getAttribute('data-dovetail-panel'); })") || []
        if mounted.empty?
          record(failures, "embed", tag, "no panel rendered inside the shadow root")
        end
        mounted.uniq.each do |mod|
          overlay = panel_overlays(mod).find { |o| o["blocking"] }
          next unless overlay
          id = safe_eval_async("window.__dovetail.overlays.open('#{mod}', '#{overlay["name"]}')")
          unless id
            record(failures, "embed", mod, "could not open overlay #{overlay["name"]}")
            next
          end
          top = safe_eval("window.__dovetail.overlays.topLayer('#{id}')")
          record(failures, "embed", mod, "overlay #{overlay["name"]} is not in the top layer") unless top == "modal"
          covered = safe_eval("(function () { var root = #{selector}; var el = root.querySelector('[data-dovetail-overlay=\"#{id}\"]'); if (!el) return false; var r = el.getBoundingClientRect(); var hit = root.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return hit != null && el.contains(hit); })()")
          record(failures, "embed", mod, "overlay #{overlay["name"]} is clipped or covered by the host page") unless covered == true
          safe_eval("window.__dovetail.overlays.close('#{id}')")
        end
        button = safe_eval("getComputedStyle(document.getElementById('host-button')).backgroundColor")
        record(failures, "embed", tag, "the host page's button lost its background (#{button})") unless button == "rgb(255, 0, 0)"
        margin = safe_eval("getComputedStyle(document.body).marginTop")
        record(failures, "embed", tag, "the host page's body lost its margin (#{margin})") unless margin == "13px"
        @exceptions.drop(exceptions_from).reject { |e| e.to_s.include?(CRASH_MARKER) }.each do |e|
          record(failures, "embed", tag, "uncaught exception: #{e}")
        end
        { "ok" => failures.empty?, "journeys" => failures }
      end

      private

      def record(failures, journey, panel, message)
        shot = screenshot("#{journey}-#{panel}")
        failures << { "code" => "D-VER-001", "journey" => journey, "panel" => panel, "message" => message, "screenshot" => shot }
      end

      def screenshot(name)
        @shot_count += 1
        path = File.join(@screenshots_dir, "#{@shot_count}-#{name.gsub(/[^a-zA-Z0-9_-]/, "_")}.png")
        @page.screenshot(path: path)
        path
      rescue StandardError
        nil
      end

      def safe_eval(js)
        raw = @page.evaluate("(() => { const __v = (#{js}); return JSON.stringify(__v === undefined ? null : __v); })()")
        raw.nil? ? nil : JSON.parse(raw)
      rescue StandardError
        nil
      end

      def safe_eval_async(js)
        wrapped = "(#{js}).then((r) => arguments[arguments.length-1](JSON.stringify(r === undefined ? true : r))).catch((e) => arguments[arguments.length-1](JSON.stringify(null)))"
        raw = @page.evaluate_async(wrapped, 10)
        raw.nil? ? nil : JSON.parse(raw)
      rescue StandardError
        nil
      end

      def overlay_journey(panels, failures)
        panels.each do |panel|
          mod = panel["module"]
          (panel_overlays(mod)).each do |overlay|
            id = safe_eval_async("window.__dovetail.overlays.open('#{mod}', '#{overlay["name"]}')")
            unless id
              record(failures, "overlay", mod, "could not open overlay #{overlay["name"]}")
              next
            end
            focused = if overlay["blocking"]
              safe_eval("window.__dovetail.focusTrapTop()") == id
            else
              safe_eval("window.__dovetail.focusInside('#{id}')") == true
            end
            unless focused
              record(failures, "overlay", mod, "focus did not move inside overlay #{overlay["name"]}")
            end
            check_top_layer(failures, "overlay", mod, overlay, id)
            if overlay["dismissible"]
              @page.keyboard.type(:escape)
              stack = safe_eval("window.__dovetail.overlays.stack()") || []
              if stack.any? { |o| o["id"] == id }
                record(failures, "overlay", mod, "overlay #{overlay["name"]} did not close on Escape")
              end
              locked = safe_eval("window.__dovetail.scrollLocked()")
              if locked && overlay["blocking"]
                record(failures, "overlay", mod, "scroll lock not released after closing #{overlay["name"]}")
              end
            else
              safe_eval("window.__dovetail.overlays.close('#{id}')")
            end
          end
        end
      end

      def stacked_overlay_journey(panels, failures)
        blocking = []
        panels.each do |panel|
          panel_overlays(panel["module"]).each do |o|
            blocking << [panel["module"], o["name"]] if o["blocking"]
          end
        end
        return if blocking.length < 2
        a_mod, a_name = blocking[0]
        b_mod, b_name = blocking[1]
        id_a = safe_eval_async("window.__dovetail.overlays.open('#{a_mod}', '#{a_name}')")
        id_b = safe_eval_async("window.__dovetail.overlays.open('#{b_mod}', '#{b_name}')")
        blocking_overlays = [[a_mod, a_name, id_a], [b_mod, b_name, id_b]]
        blocking_overlays.each do |mod, name, id|
          declared = panel_overlays(mod).find { |o| o["name"] == name } || { "name" => name, "blocking" => true }
          check_top_layer(failures, "stacked_overlays", "#{a_mod},#{b_mod}", declared, id)
        end
        stack = safe_eval("window.__dovetail.overlays.stack()") || []
        unless stack.length >= 2 && stack.last["id"] == id_b
          record(failures, "stacked_overlays", "#{a_mod},#{b_mod}", "stacking order not as expected")
        end
        safe_eval("window.__dovetail.overlays.close('#{id_b}')")
        trap = safe_eval("window.__dovetail.focusTrapTop()")
        unless trap == id_a
          record(failures, "stacked_overlays", "#{a_mod},#{b_mod}", "lower overlay did not regain its focus trap")
        end
        safe_eval("window.__dovetail.overlays.close('#{id_a}')")
      end

      def check_top_layer(failures, journey, panel, overlay, id)
        expected = overlay["blocking"] ? "modal" : "popover"
        actual = safe_eval("window.__dovetail.overlays.topLayer('#{id}')")
        return if actual == expected
        record(failures, journey, panel, "overlay #{overlay["name"]} is not in the top layer")
      end

      def route_journey(panels, failures)
        panels.each do |panel|
          panel_routes(panel["module"]).each do |route|
            safe_eval("window.__dovetail.clearRouteLog()")
            path = route.gsub(/:[a-zA-Z_]+/, "1")
            safe_eval_async("window.__dovetail.navigate('#{path}')")
            current = safe_eval("window.__dovetail.currentRoute()")
            unless current && current["module"] == panel["module"]
              record(failures, "route", panel["module"], "route #{route} did not render the owning panel")
            end
            log = safe_eval("window.__dovetail.routeLog()") || []
            other = log.select { |l| l["module"] != panel["module"] }
            unless other.empty?
              record(failures, "route", panel["module"], "another panel's route handler fired for #{route}")
            end
          end
        end
      end

      def event_journey(panels, failures)
        panels.each do |panel|
          panel_emits(panel["module"]).each do |event_id|
            consumers = panels.select { |p| panel_consumes(p["module"]).include?(event_id) }
            consumers.each { |c| navigate_to_panel(c["module"]) }
            safe_eval("window.__dovetail.clearEventLog()")
            safe_eval("window.__dovetail.emit('#{event_id}')")
            log = safe_eval("window.__dovetail.eventLog()") || []
            consumers.each do |c|
              received = log.any? { |l| l["event"] == event_id && l["receiver"] == c["module"] }
              unless received
                record(failures, "event", c["module"], "did not receive #{event_id}")
              end
            end
            non_consumers = panels.reject { |p| panel_consumes(p["module"]).include?(event_id) }
            non_consumers.each do |nc|
              received = log.any? { |l| l["event"] == event_id && l["receiver"] == nc["module"] }
              if received
                record(failures, "event", nc["module"], "received undeclared event #{event_id}")
              end
            end
          end
        end
      end

      def navigate_to_panel(mod)
        route = panel_routes(mod).first
        return unless route
        path = route.gsub(/:[a-zA-Z_]+/, "1")
        safe_eval_async("window.__dovetail.navigate('#{path}')")
      end

      def state_journey(panels, failures)
        states = %w[loading empty error unavailable ready]
        panels.each do |panel|
          mod = panel["module"]
          navigate_to_panel(mod)
          panel_views(mod).each do |view|
            states.each do |state|
              safe_eval("window.__dovetail.forceState('#{mod}', '#{view["name"]}', '#{state}')")
              safe_eval_async("window.__dovetail.unmount('#{mod}').then(function(){ return window.__dovetail.mount('#{mod}'); })")
              rendered = safe_eval("window.__dovetail.viewStates('#{mod}')") || {}
              rendered = view_states_on_home(mod) unless rendered[view["name"]]
              unless rendered[view["name"]]
                record(failures, "state", mod, "view #{view["name"]} did not render for state #{state}")
              end
              errors = safe_eval("window.__dovetail.consoleErrors()") || []
              unless errors.empty?
                record(failures, "state", mod, "console error while forcing state #{state} on #{view["name"]}")
              end
            end
            safe_eval("window.__dovetail.forceState('#{mod}', '#{view["name"]}', null)")
          end
        end
      end

      def view_states_on_home(mod)
        home = safe_eval("window.__dovetail.homeModule()")
        return {} if home.nil? || home == mod
        navigate_to_panel(home)
        states = safe_eval("window.__dovetail.viewStates('#{mod}')") || {}
        navigate_to_panel(mod)
        states
      end

      def leak_journey(panels, failures)
        panels.each do |panel|
          mod = panel["module"]
          navigate_to_panel(mod)
          safe_eval_async("window.__dovetail.unmount('#{mod}').then(function(){ return window.__dovetail.mount('#{mod}'); }).then(function(){ return window.__dovetail.unmount('#{mod}'); })")
          leaks = safe_eval("window.__dovetail.leaks('#{mod}')") || {}
          nonzero = leaks.select { |_, v| v.to_i != 0 }
          unless nonzero.empty?
            record(failures, "leak", mod, "leaks remain after unmount: #{nonzero}")
          end
          safe_eval_async("window.__dovetail.mount('#{mod}')")
        end
      end

      def slot_journey(panels, failures)
        [320, 1280].each do |width|
          safe_eval("window.__dovetail.setSlotWidth(null, #{width})")
          rects = safe_eval("window.__dovetail.slotRects()") || []
          rects.each do |r|
            if r["scroll"]["width"].to_f > r["rect"]["width"].to_f + 1
              record(failures, "slot", r["module"], "panel content wider than its slot at #{width}px")
            end
          end
        end
        safe_eval("window.__dovetail.setSlotWidth(null, null)")
      end

      def crash_journey(panels, failures)
        panels.each do |panel|
          mod = panel["module"]
          navigate_to_panel(mod)
          sleep 0.2
          crashed = safe_eval_async("window.__dovetail.crash('#{mod}')")
          unless crashed
            record(failures, "crash", mod, "crash(#{mod}) did not resolve; the panel may not be placed on the current route")
            next
          end
          sleep 0.3
          fallback_present = safe_eval("document.querySelector('[data-dovetail-panel=\"#{mod}\"] [role=alert]') != null")
          unless fallback_present
            record(failures, "crash", mod, "fallback with role alert did not render")
          end
          others = panels.reject { |p| p["module"] == mod }
          others.each do |other|
            others_ok = safe_eval("window.__dovetail.panels().find(function(p){ return p.module === '#{other["module"]}'; }).crashed === false")
            unless others_ok
              record(failures, "crash", other["module"], "stopped responding after #{mod} crashed")
            end
          end
        end
      end

      def axe_journey(panels, failures)
        axe_path = File.join(Dovetail.root, "runtime", "node_modules", "axe-core", "axe.min.js")
        return unless File.file?(axe_path)
        axe_source = File.read(axe_path)
        @page.execute(axe_source)
        panels.each do |panel|
          panel_routes(panel["module"]).each do |route|
            path = route.gsub(/:[a-zA-Z_]+/, "1")
            safe_eval_async("window.__dovetail.navigate('#{path}')")
            results = safe_eval_async("axe.run()")
            violations = (results && results["violations"]) || []
            serious = violations.select { |v| %w[serious critical].include?(v["impact"]) }
            unless serious.empty?
              record(failures, "axe", panel["module"], "axe violations: #{serious.map { |v| v["id"] }.join(", ")}")
            end
          end
        end
      end

      def global_journey(failures)
        errors = safe_eval("window.__dovetail.consoleErrors()") || []
        unless errors.empty?
          record(failures, "global", "shell", "console errors observed: #{errors.join("; ")}")
        end
        violations = safe_eval("window.__dovetail.runtimeViolations()") || []
        unless violations.empty?
          record(failures, "global", "shell", "runtime violations observed: #{violations}")
        end
        @exceptions.reject { |e| e.to_s.include?(CRASH_MARKER) }.each do |e|
          record(failures, "global", "shell", "uncaught exception: #{e}")
        end
        traffic = (@page.network.traffic rescue [])
        traffic.each do |exchange|
          if exchange.error
            url = exchange.request ? exchange.request.url : nil
            record(failures, "global", "shell", "network request failed: #{url} (#{exchange.error.error_text})")
          elsif exchange.response && exchange.response.status.to_i >= 400
            url = exchange.request ? exchange.request.url : nil
            record(failures, "global", "shell", "network request answered #{exchange.response.status}: #{url}")
          end
        end
      end

      def panel_overlays(mod)
        (@panel_entries[mod] || {})["overlays"] || []
      end

      def panel_routes(mod)
        (@panel_entries[mod] || {})["routes"] || []
      end

      def panel_emits(mod)
        ((@panel_entries[mod] || {})["emits"] || []).map { |e| e.is_a?(Hash) ? e["id"] : e }
      end

      def panel_consumes(mod)
        (@panel_entries[mod] || {})["consumes"] || []
      end

      def panel_views(mod)
        (@panel_entries[mod] || {})["views"] || []
      end
    end
  end
end
