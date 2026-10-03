require "set"
require "yaml"
require_relative "svelte_parser"
require_relative "js_scanner"
require_relative "css_parser"
require_relative "finding"
require_relative "rule_catalog"
require_relative "../tokens"

module Dovetail
  module Shape
    class Checker
      NAMED_COLORS = %w[
        black white red green blue yellow orange purple pink gray grey brown cyan magenta
        lime navy teal maroon olive silver gold indigo violet crimson coral salmon khaki
        turquoise beige ivory lavender
      ].freeze

      COMPONENTS_PATH = File.expand_path("components.yml", __dir__)

      LABEL_COMPONENTS = %w[TextInput NumberInput Select].freeze

      SPECIAL_PROPS = %w[this slot key].freeze

      GLOBAL_TARGETS = %w[window document globalThis self].freeze

      MEMBER_GLOBAL_NAMES = %w[
        document location localStorage sessionStorage indexedDB navigator history
        fetch setTimeout setInterval requestAnimationFrame XMLHttpRequest EventSource
        WebSocket postMessage eval Function
      ].freeze

      QUERY_METHODS = %w[
        querySelector querySelectorAll getElementById getElementsByClassName
        getElementsByTagName getElementsByName elementFromPoint elementsFromPoint
      ].freeze

      INSERT_REMOVE_METHODS = %w[
        appendChild append prepend insertBefore insertAdjacentElement
        insertAdjacentHTML replaceChildren removeChild
      ].freeze

      def initialize(panel_dir:, shape:, profile:, changed:)
        @panel_dir = File.expand_path(panel_dir)
        @shape = shape
        @profile = profile
        @changed = changed
        @rules = RuleCatalog.by_id
        @findings = []
        @module_name = shape["module"]
        @seen_views = Set.new
      end

      def run
        files = collect_files
        files.each do |abs_path|
          rel_path = relative_path(abs_path)
          text = begin
            File.read(abs_path)
          rescue StandardError => e
            raise Dovetail::Error.new("D-CHK-001", "could not read #{rel_path}: #{e.message}")
          end
          if abs_path.end_with?(".svelte")
            check_svelte_file(rel_path, text)
          else
            check_js_file(rel_path, text)
          end
        end
        check_missing_views
        if @changed
          @findings = @findings.select { |f| f.file == @changed }
        end
        Report.new(panel: @module_name, shape_version: @shape["contract_version"], findings: @findings)
      end

      def check_missing_views
        Array(@shape["views"]).each do |view|
          next if @seen_views.include?(view["name"])
          add("S-STATE-001", File.join("src", "Panel.svelte"), 1, 1, "view '#{view['name']}' has no <View name=\"#{view['name']}\"> in the panel")
        end
      end

      private

      def collect_files
        Dir.glob(File.join(@panel_dir, "**", "*")).select do |p|
          next false if p.include?("/node_modules/")
          File.file?(p) && p =~ /\.(svelte|ts|js)\z/
        end.sort
      end

      def relative_path(abs_path)
        abs_path.sub(/\A#{Regexp.escape(@panel_dir)}\/?/, "")
      end

      def add(rule_id, file, line, col, message, severity_override: nil)
        rule = @rules[rule_id]
        return unless rule
        severity = severity_override || RuleCatalog.severity_for(rule, @profile)
        @findings << Finding.new(file, line, col, rule_id, rule["seam"], severity, message, rule["fix"])
      end

      def check_js_file(rel_path, text)
        scope = { aliases: {}, shadowed: Set.new }
        imports, accesses, dynamic_imports = JSScanner.new(scope).scan(text, 1, 1)
        @client_bindings = build_client_bindings(imports)
        @runtime_bindings = build_runtime_bindings(imports)
        process_imports(rel_path, imports)
        process_dynamic_imports(rel_path, dynamic_imports)
        process_accesses(rel_path, accesses)
      end

      def build_client_bindings(imports)
        bindings = {}
        imports.each do |imp|
          next unless imp.source =~ %r{\A\$generated/client/([^/]+)\z}
          mod = $1
          imp.names.each { |n| bindings[n] = mod }
        end
        bindings
      end

      def build_runtime_bindings(imports)
        bindings = {}
        imports.each do |imp|
          next unless imp.source == "@dovetail/runtime"
          Array(imp.pairs).each do |orig, local|
            next if orig.nil? || orig == "*"
            bindings[local] = orig
          end
        end
        bindings
      end

      def check_svelte_file(rel_path, text)
        doc = SvelteParser.parse(text)
        doc[:errors].each do |e|
          add("S-PARSE-001", rel_path, e[:line], e[:col], "the parser did not recognise this construct")
        end
        doc[:unknown_spans].each do |span|
          scan_unknown_span(rel_path, span)
        end

        scope = { aliases: {}, shadowed: Set.new }
        all_imports = []
        all_accesses = []
        all_dynamic_imports = []
        doc[:fragments].each do |frag|
          imports, accesses, dynamic_imports = JSScanner.new(scope).scan(frag.text, frag.line, frag.col)
          all_imports.concat(imports)
          all_accesses.concat(accesses)
          all_dynamic_imports.concat(dynamic_imports)
        end
        @client_bindings = build_client_bindings(all_imports)
        @runtime_bindings = build_runtime_bindings(all_imports)
        process_imports(rel_path, all_imports)
        process_dynamic_imports(rel_path, all_dynamic_imports)
        process_accesses(rel_path, all_accesses)

        style_rules = []
        doc[:styles].each do |style|
          rules = CssParser.parse(style.text, base_line: style.line, base_col: 1)
          style_rules.concat(rules)
        end
        @local_classes = extract_local_classes(style_rules)
        check_css_rules(rel_path, style_rules)

        walk_markup(rel_path, doc[:children], is_panel_root_file: rel_path == File.join("src", "Panel.svelte"))
      end

      def extract_local_classes(rules)
        names = Set.new
        rules.each do |rule|
          selector = rule.selector.gsub(/:global\([^()]*(?:\([^()]*\)[^()]*)*\)/, "")
          selector.scan(/\.([A-Za-z_][A-Za-z0-9_-]*)/) { |m| names << m[0] }
        end
        names
      end

      def scan_unknown_span(rel_path, span)
        text = span[:text]
        line = span[:line]
        col = span[:col]
        add("S-STO-001", rel_path, line, col, "possible storage access inside an unrecognised construct") if text =~ /\b(localStorage|sessionStorage|indexedDB)\b/
        add("S-NAV-001", rel_path, line, col, "possible location access inside an unrecognised construct") if text =~ /\blocation\b/
        add("S-EVT-003", rel_path, line, col, "possible postMessage or dispatchEvent inside an unrecognised construct") if text =~ /\b(postMessage|dispatchEvent)\b/
        add("S-DAT-001", rel_path, line, col, "possible direct network access inside an unrecognised construct") if text =~ /\b(fetch|XMLHttpRequest|EventSource|WebSocket)\b/
        add("S-LIF-001", rel_path, line, col, "possible raw timer inside an unrecognised construct") if text =~ /\b(setInterval|setTimeout|requestAnimationFrame)\b/
        add("S-KEY-001", rel_path, line, col, "possible key listener inside an unrecognised construct") if text =~ /addEventListener\s*\(\s*['"](keydown|keyup|keypress)['"]/
        add("S-DYN-001", rel_path, line, col, "possible dynamic global access inside an unrecognised construct") if text =~ /\b(eval|Function)\s*\(/ || text =~ /globalThis\s*\[/
      end

      def resolved_chain(access)
        raw = access.alias_root ? (access.alias_root + access.chain.drop(1)) : access.chain
        canonicalize_chain(raw)
      end

      def canonicalize_chain(chain)
        if chain.length >= 2 && %w[window globalThis self].include?(chain[0]) && MEMBER_GLOBAL_NAMES.include?(chain[1])
          chain.drop(1)
        else
          chain
        end
      end

      def first_literal_arg(access, index = 0)
        args = access.call_args || []
        toks = args[index]
        return [nil, false] unless toks
        toks = toks.reject { |t| t.type == :comment }
        return [nil, false] if toks.empty?
        if toks.size == 1 && toks.first.type == :string
          return [toks.first.value[1..-2], true]
        end
        if toks.size == 1 && toks.first.type == :template && !toks.first.value.include?("${")
          return [toks.first.value[1..-2], true]
        end
        [nil, false]
      end

      def process_imports(rel_path, imports)
        imports.each do |imp|
          classify_import_source(rel_path, imp.source, imp.line, imp.col)
        end
      end

      def process_dynamic_imports(rel_path, dynamic_imports)
        dynamic_imports.each do |imp|
          if imp.literal
            classify_import_source(rel_path, imp.source, imp.line, imp.col)
          else
            add("S-DEP-001", rel_path, imp.line, imp.col, "import(...) with a non-literal argument cannot be checked", severity_override: "warning")
          end
        end
      end

      def classify_import_source(rel_path, source, line, col)
        if source.start_with?(".")
          target = File.expand_path(File.join(File.dirname(File.join(@panel_dir, rel_path)), source))
          unless target.start_with?(@panel_dir)
            add("S-EVT-001", rel_path, line, col, "import '#{source}' resolves outside the panel directory")
          end
          return
        end
        allowed = source == "@dovetail/runtime" ||
                  source.start_with?("@dovetail/runtime/") ||
                  source == "svelte" ||
                  source.start_with?("svelte/") ||
                  source =~ %r{\A\$generated/types/[^/]+\z} ||
                  source == "$generated/client/#{@module_name}"
        unless allowed
          add("S-DEP-001", rel_path, line, col, "import '#{source}' is outside the allowed package list")
        end
      end

      def process_accesses(rel_path, accesses)
        accesses.each do |access|
          resolved = resolved_chain(access)
          root = resolved.first
          tail = resolved.last

          if root == "location" || (resolved[0..1] == %w[window location]) || (resolved[0..1] == %w[document location])
            add("S-NAV-001", rel_path, access.line, access.col, "direct location access bypasses the router")
          end
          if root == "history" && access.call && %w[pushState replaceState back forward go].include?(tail)
            add("S-NAV-001", rel_path, access.line, access.col, "history.#{tail} bypasses the router")
          end

          if %w[localStorage sessionStorage indexedDB].include?(root)
            add("S-STO-001", rel_path, access.line, access.col, "direct #{root} access bypasses the storage seam")
          end
          if root == "document" && resolved[1] == "cookie"
            add("S-STO-001", rel_path, access.line, access.col, "document.cookie bypasses the storage seam")
          end

          if tail == "postMessage" && access.call
            add("S-EVT-003", rel_path, access.line, access.col, "postMessage bypasses the event seam")
          end
          if tail == "dispatchEvent" && access.call && (resolved.length == 1 || GLOBAL_TARGETS.include?(root))
            add("S-EVT-003", rel_path, access.line, access.col, "dispatchEvent on #{root} bypasses the event seam")
          end

          if %w[fetch XMLHttpRequest EventSource WebSocket].include?(tail) && (access.call || access.new_expr) && (resolved.length == 1 || root == "window")
            add("S-DAT-001", rel_path, access.line, access.col, "#{tail} bypasses the generated client")
          end
          if root == "navigator" && tail == "sendBeacon" && access.call
            add("S-DAT-001", rel_path, access.line, access.col, "navigator.sendBeacon bypasses the generated client")
          end

          if %w[setInterval setTimeout requestAnimationFrame requestIdleCallback].include?(tail) && access.call && (resolved.length == 1 || root == "window")
            add("S-LIF-001", rel_path, access.line, access.col, "#{tail} bypasses the lifecycle seam")
          end

          if tail == "showModal" && access.call
            add("S-OVL-002", rel_path, access.line, access.col, "dialog.showModal() bypasses the overlay host")
          end
          if root == "document" && resolved[1] == "body" && resolved[2] == "style" && access.assigned
            add("S-OVL-002", rel_path, access.line, access.col, "document.body.style writes bypass the overlay host")
          end
          if root == "document" && resolved[1] == "body" && resolved[2] == "classList" && access.call
            add("S-OVL-002", rel_path, access.line, access.col, "document.body.classList bypasses the overlay host")
          end
          if root == "document" && resolved[1] == "documentElement" && resolved[2] == "style" && resolved[3] == "overflow" && access.assigned
            add("S-OVL-002", rel_path, access.line, access.col, "document.documentElement.style.overflow bypasses the overlay host")
          end

          prefix = resolved[0...-1]
          key_event_prefixes = [[], %w[window], %w[document], %w[document body]]
          if %w[addEventListener removeEventListener].include?(tail) && access.call && key_event_prefixes.include?(prefix)
            key, literal = first_literal_arg(access)
            if literal && %w[keydown keyup keypress].include?(key)
              add("S-KEY-001", rel_path, access.line, access.col, "#{tail}('#{key}', ...) bypasses the shortcut seam")
            end
          end
          if %w[onkeydown onkeyup onkeypress].include?(tail) && access.assigned && key_event_prefixes.include?(prefix)
            add("S-KEY-001", rel_path, access.line, access.col, "#{tail} bypasses the shortcut seam")
          end

          if access.computed && %w[window globalThis self document].include?(root)
            add("S-DYN-001", rel_path, access.line, access.col, "computed access on #{root} hides the seam from the checker")
          end
          if %w[eval Function].include?(tail) && resolved.length == 1
            add("S-DYN-001", rel_path, access.line, access.col, "#{tail} hides the seam from the checker")
          end

          if root == "document" && access.call && QUERY_METHODS.include?(tail)
            add("S-LAY-004", rel_path, access.line, access.col, "document.#{tail}(...) reaches the page outside the slot")
          end
          if access.call && INSERT_REMOVE_METHODS.include?(tail) && (prefix == %w[document body] || prefix == %w[document documentElement])
            add("S-LAY-004", rel_path, access.line, access.col, "#{prefix.join('.')}.#{tail}(...) reaches the page outside the slot")
          end

          check_seam_call(rel_path, access)
          check_client_call(rel_path, access)
        end
      end

      def check_seam_call(rel_path, access)
        return unless access.call
        return unless access.chain.length == 1
        local_name = access.chain.first
        primitive = @runtime_bindings && @runtime_bindings[local_name]
        return unless primitive
        case primitive
        when "openOverlay"
          value, literal = first_literal_arg(access)
          overlays = Array(@shape["overlays"]).map { |o| o["name"] }
          if literal
            unless overlays.include?(value)
              add("S-OVL-003", rel_path, access.line, access.col, "#{local_name}('#{value}') is not declared in the shape")
            end
          else
            add("S-OVL-003", rel_path, access.line, access.col, "#{local_name} called with a name that cannot be checked", severity_override: "warning")
          end
        when "navigate", "link"
          value, literal = first_literal_arg(access)
          routes = Array(@shape["routes"])
          if literal
            unless routes.include?(value)
              add("S-NAV-002", rel_path, access.line, access.col, "#{local_name}('#{value}') is not one of the shape's routes")
            end
          else
            add("S-NAV-002", rel_path, access.line, access.col, "#{local_name} called with a route that cannot be checked", severity_override: "warning")
          end
        when "emit"
          value, literal = first_literal_arg(access)
          emits = Array(@shape.dig("events", "emits"))
          if literal
            unless emits.include?(value)
              add("S-EVT-002", rel_path, access.line, access.col, "#{local_name}('#{value}') is not declared in the shape's emits")
            end
          else
            add("S-EVT-002", rel_path, access.line, access.col, "#{local_name} called with an event name that cannot be checked", severity_override: "warning")
          end
        when "on"
          value, literal = first_literal_arg(access)
          consumes = Array(@shape.dig("events", "consumes"))
          if literal
            unless consumes.include?(value)
              add("S-EVT-002", rel_path, access.line, access.col, "#{local_name}('#{value}') is not declared in the shape's consumes")
            end
          else
            add("S-EVT-002", rel_path, access.line, access.col, "#{local_name} called with an event name that cannot be checked", severity_override: "warning")
          end
        when "t"
          value, literal = first_literal_arg(access)
          if literal
            unless value.start_with?("#{@module_name}.")
              add("S-I18N-001", rel_path, access.line, access.col, "#{local_name}('#{value}') is missing the module prefix")
            end
          else
            add("S-I18N-001", rel_path, access.line, access.col, "#{local_name} called with a key that cannot be checked", severity_override: "warning")
          end
        end
      end

      def check_client_call(rel_path, access)
        return unless access.call
        return unless access.chain.length == 2
        binding_name = access.chain.first
        op = access.chain.last
        return unless @client_bindings && @client_bindings[binding_name] == @module_name
        operations = Array(@shape["operations"])
        qualified = "#{@module_name}.#{op}"
        unless operations.include?(qualified)
          add("S-DAT-002", rel_path, access.line, access.col, "#{binding_name}.#{op}(...) is not a declared operation")
        end
      end

      def check_css_rules(rel_path, rules)
        rules.each do |rule|
          if rule.selector =~ /:global|(?<![\w-]):root\b|(?<![\w-])html\b|(?<![\w-])body\b/
            add("S-CSS-004", rel_path, rule.line, rule.col, "selector '#{rule.selector}' reaches outside the component")
          end
          rule.declarations.each { |decl| check_declaration(rel_path, decl) }
        end
      end

      def check_declaration(rel_path, decl)
        prop = decl.property.downcase
        value = decl.value

        if prop == "z-index"
          add("S-LAY-002", rel_path, decl.line, decl.col, "z-index outside the overlay host")
        end
        if prop == "position" && value.strip.downcase == "fixed"
          add("S-OVL-001", rel_path, decl.line, decl.col, "position: fixed escapes the shared stacking order")
        end
        if value =~ /\b\d+(\.\d+)?(dvh|svh|lvh|dvw|svw|lvw|vh|vw|vmin|vmax)\b/
          add("S-LAY-001", rel_path, decl.line, decl.col, "viewport units assume the panel owns the page")
        end
        if prop =~ /\Amargin/ && value =~ /-\d/
          add("S-LAY-003", rel_path, decl.line, decl.col, "negative margin paints over the neighbouring slot")
        end
        css_violation = css_value_literal(prop, value)
        if css_violation
          add("S-CSS-003", rel_path, decl.line, decl.col, css_violation)
        end
      end

      def css_value_literal(prop, value)
        return nil if value.nil? || value.strip.empty?
        if %w[box-shadow text-shadow].include?(prop)
          return nil if value.strip.downcase == "none"
          stripped = value.gsub(/var\([^()]*(?:\([^()]*\)[^()]*)*\)/, "")
          return "literal #{prop} value" unless stripped.strip.empty?
          return nil
        end
        split_top_level(value).each do |tok|
          bad = css_token_violation(prop, tok)
          return bad if bad
        end
        nil
      end

      def split_top_level(value)
        parts = []
        depth = 0
        buf = +""
        value.each_char do |c|
          depth += 1 if c == "("
          depth -= 1 if c == ")"
          if (c == " " || c == "\t" || c == ",") && depth <= 0
            parts << buf unless buf.strip.empty?
            buf = +""
          else
            buf << c
          end
        end
        parts << buf unless buf.strip.empty?
        parts
      end

      def css_token_violation(prop, tok)
        t = tok.strip
        return nil if t.empty?
        return nil if %w[auto inherit none 100% 0 0px 0s 0ms].include?(t.downcase)
        return nil if t.downcase == "currentcolor" || t.downcase == "transparent"
        if t =~ /\Avar\(\s*(--[a-zA-Z0-9_-]+)/
          name = $1.sub(/\A--/, "")
          return nil if Dovetail::Tokens.theme_keys.include?(name)
          return "var(#{$1}) is not a vocabulary or host token"
        end
        return "literal colour #{t}" if t =~ /\A#[0-9a-fA-F]{3,8}\z/
        return "literal colour #{t}" if t =~ /\A(rgb|rgba|hsl|hsla|hwb|lab|lch|oklab|oklch|color)\(/i
        if t =~ /\A-?\d+(\.\d+)?(px|rem|em|pt|pc|cm|mm|in|ex|ch)\z/i
          num = t.to_f
          unit = t[/[a-zA-Z%]+\z/].downcase
          if unit == "px" && num == 0
            return nil
          end
          if unit == "px" && num.abs <= 2 && prop =~ /\A(border(-(top|right|bottom|left))?(-width)?|outline|outline-width)\z/
            return nil
          end
          return "literal length #{t}"
        end
        if t =~ /\A-?\d+(\.\d+)?(ms|s)\z/i && prop =~ /\A(transition(-duration)?|animation(-duration)?)\z/
          return "literal time #{t}"
        end
        return nil if t =~ /\A-?\d+(\.\d+)?(%|fr|cqw|cqh|cqi|cqb|cqmin|cqmax)\z/i
        return nil if t =~ /\A-?\d+(\.\d+)?\z/
        return "literal colour #{t}" if NAMED_COLORS.include?(t.downcase)
        nil
      end

      def walk_markup(rel_path, nodes, is_panel_root_file:, top_level: true, heading_context: nil)
        nodes.each do |node|
          case node
          when ElementNode
            check_element(rel_path, node, is_root: top_level && is_panel_root_file)
            walk_markup(rel_path, node.children, is_panel_root_file: is_panel_root_file, top_level: false)
          when BlockNode
            node.branches.each do |branch|
              walk_markup(rel_path, branch[:children], is_panel_root_file: is_panel_root_file, top_level: false)
            end
          when HtmlTagNode
            add("S-HTML-004", rel_path, node.line, node.col, "{@html} can carry script into every panel")
          end
        end
        check_states(rel_path, nodes)
      end

      def check_element(rel_path, node, is_root:)
        tag = node.tag
        attrs = node.attrs

        if %w[main nav].include?(tag.downcase)
          add("S-HTML-001", rel_path, node.line, node.col, "<#{tag}> is a landmark the shell owns")
        end
        role = static_attr(attrs, "role")
        if role && %w[banner navigation contentinfo main].include?(role)
          add("S-HTML-001", rel_path, node.line, node.col, "role=\"#{role}\" is a landmark the shell owns")
        end

        if tag.downcase == "h1"
          add("S-HTML-002", rel_path, node.line, node.col, "h1 is reserved for the page outline the shell owns")
        elsif tag.downcase == "h2" && !panel_has_main_or_full_slot?
          add("S-HTML-002", rel_path, node.line, node.col, "h2 starts above this panel's declared slot level")
        end

        %w[id for aria-labelledby aria-describedby aria-controls aria-owns aria-activedescendant list form headers].each do |name|
          attr = attrs.find { |a| a.name == name }
          next unless attr
          if attr.kind == :static && attr.value && !attr.value.to_s.empty?
            add("S-ID-001", rel_path, attr.line, attr.col, "literal #{name}=\"#{attr.value}\" collides across panels")
          end
        end

        check_class_attrs(rel_path, node, is_root: is_root)
        check_style_attrs(rel_path, node, is_root: is_root)

        check_component_props(rel_path, node)

        if %w[input select textarea].include?(tag.downcase)
          unless labeled?(attrs)
            add("S-HTML-003", rel_path, node.line, node.col, "<#{tag}> has no accessible label")
          end
        end
        if LABEL_COMPONENTS.include?(tag)
          unless labeled?(attrs)
            add("S-HTML-003", rel_path, node.line, node.col, "<#{tag}> outside a <Field> has no label")
          end
        end

        if %w[svelte:window svelte:document svelte:body].include?(tag.downcase)
          attrs.each do |attr|
            if %w[onkeydown onkeyup onkeypress].include?(attr.name)
              add("S-KEY-001", rel_path, attr.line, attr.col, "#{attr.name} on #{tag} bypasses the shortcut seam")
            end
            if attr.name.start_with?("on:") && %w[keydown keyup keypress].include?(attr.name.sub("on:", ""))
              add("S-KEY-001", rel_path, attr.line, attr.col, "#{attr.name} on #{tag} bypasses the shortcut seam")
            end
          end
        end
      end

      def panel_has_main_or_full_slot?
        Array(@shape["slots"]).any? { |s| %w[main full].include?(s["size"]) }
      end

      def static_attr(attrs, name)
        attr = attrs.find { |a| a.name == name }
        return nil unless attr
        attr.kind == :static ? attr.value : nil
      end

      def components
        @@components ||= YAML.safe_load(File.read(COMPONENTS_PATH), permitted_classes: [], aliases: false).fetch("components")
      end

      def check_component_props(rel_path, node)
        return if @profile == "relaxed"
        original = (@runtime_bindings || {})[node.tag]
        entry = original && components[original]
        return unless entry
        return if entry["rest"]
        props = entry["props"]
        node.attrs.each do |attr|
          name = prop_name(attr)
          next if name.nil? || SPECIAL_PROPS.include?(name) || props.include?(name)
          add("S-PROP-001", rel_path, attr.line, attr.col, "<#{node.tag}> has no prop #{name}; its props are #{props.join(', ')}")
        end
      end

      def prop_name(attr)
        return nil if attr.kind == :spread
        name = attr.name
        return nil if name.start_with?("@")
        if name.include?(":")
          prefix, rest = name.split(":", 2)
          return prefix == "bind" ? rest : nil
        end
        name
      end

      def labeled?(attrs)
        return true if attrs.any? { |a| %w[aria-label aria-labelledby title].include?(a.name) }
        return true if attrs.any? { |a| a.name == "label" }
        return true if attrs.any? { |a| a.kind == :spread }
        false
      end

      def class_refusal_message(cls, rule_id, suggestion)
        if rule_id == "S-CSS-001"
          suggestion ? "class '#{cls}' is outside the tokens; use #{suggestion}" : "class '#{cls}' is outside the tokens"
        else
          "class '#{cls}' is refused"
        end
      end

      def check_class_attrs(rel_path, node, is_root:)
        node.attrs.each do |attr|
          if attr.name == "class"
            classes = extract_literal_classes(attr)
            if classes.nil?
              add("S-CSS-005", rel_path, attr.line, attr.col, "the class attribute is not a literal the checker can resolve")
              next
            end
            classes.each do |cls|
              if is_root && cls =~ /\A-(m|mx|my|mt|mr|mb|ml)-/
                add("S-LAY-003", rel_path, attr.line, attr.col, "negative margin on the panel's root element")
              end
              next if @local_classes && @local_classes.include?(cls)
              status, rule_id, suggestion = Tokens::ClassGrammar.classify(cls)
              next if status == :ok
              add(rule_id, rel_path, attr.line, attr.col, class_refusal_message(cls, rule_id, suggestion))
            end
          elsif attr.name.start_with?("class:")
            cls = attr.name.sub("class:", "")
            next if @local_classes && @local_classes.include?(cls)
            status, rule_id, suggestion = Tokens::ClassGrammar.classify(cls)
            next if status == :ok
            add(rule_id, rel_path, attr.line, attr.col, class_refusal_message(cls, rule_id, suggestion))
          end
        end
      end

      def extract_literal_classes(attr)
        return attr.value.to_s.split(/\s+/) if attr.kind == :static
        text = attr.value.to_s.strip
        return nil if attr.kind != :expression && attr.kind != :mixed
        if text =~ /\A'([^']*)'\z/ || text =~ /\A"([^"]*)"\z/
          return $1.split(/\s+/)
        end
        return nil if text.include?("${")
        if text =~ /\A`([^`]*)`\z/
          return $1.split(/\s+/)
        end
        literals = []
        skeleton = text.dup
        skeleton = skeleton.gsub(/'([^']*)'/) { literals << $1; "\0" }
        skeleton = skeleton.gsub(/"([^"]*)"/) { literals << $1; "\0" }
        remaining = skeleton.gsub("\0", "").strip
        if !literals.empty? && remaining =~ /\A[\s?:&|!=<>()a-zA-Z_$,\[\].]*\z/
          return literals.flat_map { |l| l.split(/\s+/) }
        end
        nil
      end

      def check_style_attrs(rel_path, node, is_root:)
        node.attrs.each do |attr|
          if attr.name == "style" && attr.kind == :static
            decls = CssParser.parse_declarations(attr.value, base_line: attr.line, base_col: attr.col + attr.name.length + 2)
            decls.each { |decl| check_declaration(rel_path, decl) }
            if is_root
              decls.each do |decl|
                if decl.property.downcase =~ /\Amargin/ && decl.value =~ /-\d/
                  add("S-LAY-003", rel_path, decl.line, decl.col, "negative margin on the panel's root element")
                end
              end
            end
          elsif attr.name.start_with?("style:")
            prop = attr.name.sub("style:", "")
            value = attr.value.to_s
            if value.include?("'fixed'") || value.include?("\"fixed\"") || value.strip == "fixed"
              if prop == "position"
                add("S-OVL-001", rel_path, attr.line, attr.col, "style:position={'fixed'} escapes the shared stacking order")
              end
            end
          end
        end
      end

      def check_states(rel_path, nodes)
        nodes.each do |node|
          next unless node.is_a?(ElementNode)
          if node.tag == "View"
            name_attr = node.attrs.find { |a| a.name == "name" }
            view_name = name_attr && name_attr.kind == :static ? name_attr.value : nil
            @seen_views << view_name if view_name
            view = Array(@shape["views"]).find { |v| v["name"] == view_name }
            if view
              required = Array(view["states"])
              if has_states_element?(node.children)
                missing = []
              else
                covered = states_covered_via_conditionals(node.children)
                missing = required - covered.to_a
              end
              unless missing.empty?
                add("S-STATE-001", rel_path, node.line, node.col, "view '#{view_name}' is missing #{missing.join(', ')}")
              end
            end
          end
        end
      end

      def has_states_element?(nodes)
        nodes.each do |node|
          case node
          when ElementNode
            return true if node.tag == "States"
            return true if has_states_element?(node.children)
          when BlockNode
            node.branches.each do |b|
              return true if has_states_element?(b[:children])
            end
          end
        end
        false
      end

      def states_covered_via_conditionals(nodes)
        covered = Set.new
        nodes.each do |node|
          case node
          when ElementNode
            covered.merge(states_covered_via_conditionals(node.children))
          when BlockNode
            if node.keyword == "if"
              node.branches.each do |b|
                %w[loading empty error unavailable ready].each do |state|
                  covered << state if b[:expr].to_s.include?("'#{state}'") || b[:expr].to_s.include?("\"#{state}\"")
                end
                covered.merge(states_covered_via_conditionals(b[:children]))
              end
            end
          end
        end
        covered
      end
    end
  end
end
