require "json"
require "fileutils"
require_relative "fuse/collisions"
require_relative "fuse/tailwind"
require_relative "fuse/registry"
require_relative "fuse/prefetch"
require_relative "fuse/bind"
require_relative "fuse/live"

module Dovetail
  class Fuse
    def self.run(app:, panel_dirs:, verify: false, out: nil, development: false, live: [], embed: false)
      new(app: app, panel_dirs: panel_dirs, verify: verify, out: out, development: development, live: live, embed: embed).run
    end

    def initialize(app:, panel_dirs:, verify: false, out: nil, development: false, live: [], embed: false)
      @app_dir = File.expand_path(app)
      @config = Dovetail::Config.find(@app_dir) || raise(Dovetail::Error.new("D-CFG-001", "no dovetail.yml found above #{@app_dir}"))
      @panel_dirs = (panel_dirs && !panel_dirs.empty? ? panel_dirs : @config.panels).map { |p| File.expand_path(p) }
      @verify = verify
      @out = out ? File.expand_path(out) : @config.out
      @development = development
      @live_globs = (@config.live + Array(live)).uniq
      @embed = embed || @config.embed
      @live_config = { "enabled" => false, "base" => @config.live_base, "moduleIds" => [], "entries" => [] }
      @report = { "panels" => [], "steps" => {}, "duration_ms" => 0 }
    end

    def run
      started = now_ms
      @config.validate_embed_tag! if @embed
      generated_dir = File.join(@out, "generated")
      models = []
      shapes = {}
      module_dirs = {}

      contracts_step do
        contract_paths = @config.contracts.dup
        panel_contract_of = {}
        @panel_dirs.each do |panel_dir|
          contract_path = File.expand_path(File.join(panel_dir, "..", "contract.rb"))
          unless File.file?(contract_path)
            raise Dovetail::Error.new("D-FUS-001", "no contract.rb found for panel #{panel_dir}")
          end
          panel_contract_of[contract_path] = panel_dir
          contract_paths << contract_path unless contract_paths.include?(contract_path)
        end

        contract_paths.uniq.each do |contract_path|
          model = Dovetail::Contract.load_file(contract_path)
          models << model
          if panel_contract_of[contract_path]
            module_dirs[model.to_h["module"]] = panel_contract_of[contract_path]
          end
        end

        findings = Dovetail::Contract.validate(models)
        errors = findings.select { |f| f.severity == "error" }
        unless errors.empty?
          raise Dovetail::Error.new("D-CON-002", "contract validation failed", findings: findings.map { |f| f.to_h rescue { "rule" => f.rule, "message" => f.message } })
        end

        models.each do |model|
          model_hash = model.to_h
          prev_path = File.join(generated_dir, "model", "#{model_hash["module"]}.model.json")
          next unless File.file?(prev_path)
          prev_hash = JSON.parse(File.read(prev_path))
          changes = Dovetail::Contract.diff(prev_hash, model_hash)
          unless Dovetail::Contract.version_ok?(prev_hash, model_hash, changes)
            raise Dovetail::Error.new("D-CON-003", "breaking change without a version increase (still v#{model_hash["version"]}) in #{model_hash["module"]}")
          end
        end

        Dovetail::Compiler.compile(models, out: generated_dir)

        models.each do |model|
          mod = model.to_h["module"]
          shape_path = File.join(generated_dir, "shape", "#{mod}.shape.json")
          shapes[mod] = JSON.parse(File.read(shape_path)) if File.file?(shape_path)
        end

        @report["contract_versions"] = models.each_with_object({}) { |m, h| h[m.to_h["module"]] = m.to_h["version"] }
        { "ok" => true, "modules" => models.map { |m| m.to_h["module"] } }
      end

      checks_step do
        results = {}
        shapes.each do |mod, shape|
          panel_dir = module_dirs[mod]
          report = Dovetail::Shape.check(panel_dir: panel_dir, shape: shape, profile: @config.rules_profile)
          results[mod] = report.to_h
          if report.errors > 0
            raise Dovetail::Error.new("D-FUS-001", "panel #{mod} failed its checks", findings: report.to_h["findings"])
          end
        end
        results
      end

      type_check_step do
        if @config.node == false
          { "skipped" => true }
        else
          node_bin = @config.node
          svelte_check_bin = File.join(dovetail_root, "runtime", "node_modules", ".bin", "svelte-check")
          if node_bin == false || !File.exist?(svelte_check_bin)
            { "skipped" => true }
          else
            FileUtils.mkdir_p(File.join(@out, "bind"))
            shapes.keys.each do |mod|
              File.write(File.join(@out, "bind", "#{mod}.ts"), Dovetail::Fuse::Bind.generate(mod))
            end
            results = {}
            shapes.keys.each do |mod|
              tsconfig_dir = File.join(@out, "typecheck", mod)
              FileUtils.mkdir_p(tsconfig_dir)
              tsconfig = {
                "compilerOptions" => {
                  "moduleResolution" => "bundler",
                  "target" => "ES2022",
                  "strict" => true,
                  "baseUrl" => ".",
                  "paths" => {
                    "@dovetail/runtime" => [File.join(dovetail_root, "runtime", "dist", "index")],
                    "@dovetail/runtime/*" => [File.join(dovetail_root, "runtime", "dist", "*")],
                    "$generated/*" => [File.join(generated_dir, "*")]
                  }
                },
                "include" => [module_dirs[mod]]
              }
              File.write(File.join(tsconfig_dir, "tsconfig.json"), JSON.pretty_generate(tsconfig) + "\n")
              out_text = `#{node_bin} #{svelte_check_bin} --tsconfig #{tsconfig_dir}/tsconfig.json 2>&1`
              ok = $?.success?
              results[mod] = { "ok" => ok, "output" => out_text }
              unless ok
                raise Dovetail::Error.new("D-FUS-001", "type check failed for #{mod}", output: out_text)
              end
            end
            results
          end
        end
      end

      collisions_step do
        route_collisions = Dovetail::Fuse::Collisions.route_collisions(shapes)
        shortcut_collisions = Dovetail::Fuse::Collisions.shortcut_collisions(shapes)
        overlay_collisions = Dovetail::Fuse::Collisions.overlay_collisions(shapes)
        storage_collisions = Dovetail::Fuse::Collisions.storage_key_collisions(shapes)

        all_emitters = {}
        models.each do |model|
          mod = model.to_h["module"]
          (model.to_h["emits"] || {}).keys.each { |name| all_emitters["#{mod}.#{name}"] = mod }
        end
        event_problems = Dovetail::Fuse::Collisions.event_findings(shapes, all_emitters)

        unless route_collisions.empty? && shortcut_collisions.empty? && overlay_collisions.empty?
          raise Dovetail::Error.new("D-FUS-002", "cross-panel collisions detected", routes: route_collisions, shortcuts: shortcut_collisions, overlays: overlay_collisions)
        end
        unless event_problems.empty?
          raise Dovetail::Error.new("D-FUS-003", "undeclared consumed events", events: event_problems)
        end
        { "routes" => route_collisions, "shortcuts" => shortcut_collisions, "overlays" => overlay_collisions, "storage" => storage_collisions }
      end

      themes_step do
        theme_paths = @config.themes
        if theme_paths.empty?
          raise Dovetail::Error.new("D-TOK-001", "at least one theme is required")
        end
        required_keys = Dovetail::Tokens.theme_keys
        theme_paths.each do |path|
          theme = JSON.parse(File.read(path))
          present = theme["tokens"].keys
          missing = required_keys - present
          unless missing.empty?
            raise Dovetail::Error.new("D-TOK-001", "theme #{theme["id"]} is missing tokens #{missing.join(", ")}")
          end
        end
        { "checked" => theme_paths.map { |p| File.basename(p) } }
      end

      layout = Dovetail::Layout.load(@config.layout)

      generate_step do
        panel_models = models.select { |m| module_dirs.key?(m.to_h["module"]) }

        FileUtils.mkdir_p(File.join(@out, "bind"))
        panel_models.each do |model|
          mod = model.to_h["module"]
          File.write(File.join(@out, "bind", "#{mod}.ts"), Dovetail::Fuse::Bind.generate(mod))
        end

        theme_infos = @config.themes.map do |path|
          theme = JSON.parse(File.read(path))
          { id: theme["id"], path: path }
        end

        panel_infos = panel_models.map do |model|
          mod = model.to_h["module"]
          entry_path = File.join(generated_dir, "registry", "#{mod}.json")
          entry = File.file?(entry_path) ? JSON.parse(File.read(entry_path)) : {}
          {
            module: mod,
            entry: entry,
            panel_svelte_path: File.join(module_dirs[mod], "src", "Panel.svelte"),
            schema_path: File.join(generated_dir, "schema", "#{mod}.schema.json"),
            messages_paths: locale_messages(File.join(module_dirs[mod], "messages"))
          }
        end

        shell_messages_paths = locale_messages(File.join(@config.shell, "messages"))

        live_files = Dovetail::Fuse::Live.resolve_files(@live_globs, @config.root)
        if live_files.any?
          live_plan = Dovetail::Fuse::Live.plan(live_files, @config.root, @config.live_base, module_dirs)
          live_entries = Dovetail::Fuse::Live.write_entries(live_plan, @out)
          Dovetail::Fuse::Live.write_bind_sources(panel_models.map { |m| m.to_h["module"] }, @out)
          @live_config = {
            "enabled" => true,
            "base" => @config.live_base,
            "moduleIds" => panel_models.map { |m| m.to_h["module"] },
            "entries" => live_entries
          }
        end

        registry_ts = Dovetail::Fuse::Registry.generate(
          panels: panel_infos,
          layout: layout,
          themes: theme_infos,
          shell_messages_paths: shell_messages_paths,
          development: @development
        )
        File.write(File.join(@out, "registry.generated.ts"), registry_ts)

        registry_development_ts = Dovetail::Fuse::Registry.generate(
          panels: panel_infos,
          layout: layout,
          themes: theme_infos,
          shell_messages_paths: shell_messages_paths,
          development: true
        )
        File.write(File.join(@out, "registry.development.generated.ts"), registry_development_ts)

        File.write(File.join(@out, "prefetch.json"), Dovetail::CanonicalJSON.pretty(Dovetail::Fuse::Prefetch.manifest(panel_infos.map { |p| p[:entry] }, layout)))

        vocabulary = Dovetail::Tokens.vocabulary
        css = Dovetail::Fuse::Tailwind.entry_css(vocabulary, @panel_dirs, @config.shell, live: @live_config["enabled"])
        File.write(File.join(@out, "app.css"), css)

        embed_generated = []
        if @embed && !@live_config["enabled"]
          File.write(File.join(@out, "embed.generated.ts"), embed_entry_source)
          embed_generated << "embed.generated.ts"
        end

        { "generated" => ["registry.generated.ts", "registry.development.generated.ts", "prefetch.json", "app.css"] + panel_models.map { |m| "bind/#{m.to_h["module"]}.ts" } + embed_generated }
      end

      dir_to_module = module_dirs.each_with_object({}) { |(mod, dir), h| h[dir] = mod }

      build_step do
        if @config.node == false
          result = { "skipped" => true }
          result["embed"] = { "skipped" => "node unavailable" } if @embed
          result
        else
          dist = File.join(@out, "dist")
          build_config = {
            root: @config.shell,
            outDir: dist,
            development: false,
            panels: @panel_dirs.map { |d| { module: dir_to_module[d], dir: d } },
            out: @out,
            runtime: File.join(dovetail_root, "runtime"),
            live: @live_config
          }
          result = run_node_build(build_config, dist)
          if @live_config["enabled"]
            File.write(File.join(dist, ".dovetail-live.json"), JSON.generate("live_base" => @config.live_base, "root" => @config.root))
          end
          if @embed
            if @live_config["enabled"]
              result["embed"] = { "skipped" => "live components need the application's import map" }
            else
              tag = @config.embed_tag
              run_node_build(embed_build_config(build_config, File.join(dist, "embed"), false), File.join(dist, "embed"))
              result["embed"] = { "ok" => true, "path" => File.join(dist, "embed", "#{tag}.js"), "tag" => tag }
            end
          end
          result
        end
      end

      verify_step do
        if @verify
          if @config.node == false
            { "skipped" => "node unavailable" }
          else
            verify_dist = File.join(@out, "verify-build")
            verify_config = {
              root: @config.shell,
              outDir: verify_dist,
              development: true,
              panels: @panel_dirs.map { |d| { module: dir_to_module[d], dir: d } },
              out: @out,
              runtime: File.join(dovetail_root, "runtime"),
              live: @live_config
            }
            run_node_build(verify_config, verify_dist)
            if @live_config["enabled"]
              File.write(File.join(verify_dist, ".dovetail-live.json"), JSON.generate("live_base" => @config.live_base, "root" => @config.root))
            end
            if @embed && !@live_config["enabled"]
              tag = @config.embed_tag
              run_node_build(embed_build_config(verify_config, File.join(verify_dist, "embed"), true), File.join(verify_dist, "embed"))
              File.write(File.join(verify_dist, "embed-host.html"), embed_host_html(tag))
              File.write(File.join(verify_dist, ".dovetail-embed.json"), JSON.generate("tag" => tag))
            end
            result = Dovetail::Verify.run(build_dir: verify_dist, screenshots_dir: File.join(@out, "screenshots"))
            if result["ok"] == false
              raise Dovetail::Error.new("D-VER-001", "a composition journey failed", journeys: result["journeys"])
            end
            result
          end
        else
          { "skipped" => true }
        end
      end

      @report["duration_ms"] = now_ms - started
      @report["panels"] = models.select { |m| module_dirs.key?(m.to_h["module"]) }.map { |m| m.to_h["module"] }
      write_report
      @report
    end

    private

    def locale_messages(messages_dir)
      return {} unless Dir.exist?(messages_dir)
      Dir.glob(File.join(messages_dir, "*.json")).each_with_object({}) do |path, h|
        h[File.basename(path, ".json")] = path
      end
    end

    def embed_entry_source
      [
        "import css from '$dovetail/app.css?inline';",
        "import App from '#{File.join(@config.shell, "App.svelte")}';",
        "import { defineDovetailApp } from '@dovetail/runtime/embed';",
        "defineDovetailApp('#{@config.embed_tag}', App, css);",
        ""
      ].join("\n")
    end

    def embed_build_config(base, out_dir, development)
      base.merge(
        development: development,
        embed: {
          enabled: true,
          only: true,
          tag: @config.embed_tag,
          entry: File.join(@out, "embed.generated.ts"),
          outDir: out_dir
        }
      )
    end

    def embed_host_html(tag)
      html = <<~'HTML'
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>Embed host</title>
        <style>
        * { box-sizing: content-box; font-family: serif }
        body { margin: 13px }
        button { background: rgb(255, 0, 0); border: 5px solid rgb(0, 255, 0) }
        div { line-height: 3 }
        #hostile-header { position: fixed; top: 0; left: 0; right: 0; height: 40px; z-index: 2147483647; background: rgb(0, 0, 0) }
        #hostile-wrap { position: relative; z-index: 1; overflow: hidden; transform: translateZ(0); height: 320px; margin-top: 60px }
        </style>
        <script>
        window.__embedReady = false;
        document.addEventListener('dovetail-ready', function () { window.__embedReady = true; });
        </script>
        </head>
        <body>
        <div id="hostile-header"></div>
        <button id="host-button">host</button>
        <div id="hostile-wrap"><__TAG__></__TAG__></div>
        <script type="module" src="./embed/__TAG__.js"></script>
        </body>
        </html>
      HTML
      html.gsub("__TAG__", tag)
    end

    def dovetail_root
      Dovetail.root
    end

    def now_ms
      (Time.now.to_f * 1000).to_i
    end

    def step(name)
      begin
        result = yield
        @report["steps"][name] = result
        result
      rescue Dovetail::Error => e
        @report["steps"][name] = { "ok" => false, "code" => e.code, "message" => e.message, "details" => e.details }
        write_report
        raise e
      end
    end

    def contracts_step(&block); step("contracts", &block); end
    def checks_step(&block); step("checks", &block); end
    def type_check_step(&block); step("type_check", &block); end
    def collisions_step(&block); step("collisions", &block); end
    def themes_step(&block); step("themes", &block); end
    def generate_step(&block); step("generate", &block); end
    def build_step(&block); step("build", &block); end
    def verify_step(&block); step("verify", &block); end

    def write_report
      FileUtils.mkdir_p(@out)
      File.write(File.join(@out, "fuse-report.json"), Dovetail::CanonicalJSON.pretty(@report))
    end

    def ensure_node_modules_link
      link_path = File.join(@config.root, "node_modules")
      target = File.join(dovetail_root, "runtime", "node_modules")
      return unless File.directory?(target)
      return if File.symlink?(link_path) && File.readlink(link_path) == target
      File.delete(link_path) if File.exist?(link_path) || File.symlink?(link_path)
      File.symlink(target, link_path)
    rescue StandardError
      nil
    end

    def run_node_build(build_config, dist)
      FileUtils.mkdir_p(@out)
      ensure_node_modules_link
      config_path = File.join(@out, "build-config-#{object_id}.json")
      File.write(config_path, JSON.generate(build_config))
      node_bin = @config.node
      script = File.join(dovetail_root, "runtime", "tools", "fuse-build.mjs")
      output = `#{node_bin} #{script} #{config_path} 2>&1`
      ok = $?.success?
      File.delete(config_path) if File.exist?(config_path)
      unless ok
        raise Dovetail::Error.new("D-FUS-004", "build failed", output: output)
      end
      { "ok" => true, "outDir" => dist }
    end
  end
end
