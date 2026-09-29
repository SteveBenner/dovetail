require "json"
require "fileutils"
require "tmpdir"
require "socket"
require_relative "fuse/collisions"
require_relative "fuse/tailwind"
require_relative "fuse/registry"
require_relative "fuse/bind"

module Dovetail
  class Dev
    def initialize(app:, panel_dirs:, backend: nil, static: false, port: 5173)
      @app_dir = File.expand_path(app)
      @config = Dovetail::Config.find(@app_dir) || raise(Dovetail::Error.new("D-CFG-001", "no dovetail.yml found above #{@app_dir}"))
      @panel_dirs = (panel_dirs && !panel_dirs.empty? ? panel_dirs : @config.panels).map { |p| File.expand_path(p) }
      @backend = backend
      @static = static
      @port = port
      @out = @config.out
      @mtimes = {}
    end

    def run(stdout:, stderr:)
      compile_and_check(stdout: stdout, stderr: stderr)
      write_findings

      if @static
        serve_static(stdout: stdout)
      else
        if @config.node == false
          stderr.puts("dovetail dev: node is disabled in dovetail.yml; use --static")
          return 2
        end
        serve_vite(stdout: stdout, stderr: stderr)
      end
      0
    end

    private

    def module_for(panel_dir)
      contract_path = File.expand_path(File.join(panel_dir, "..", "contract.rb"))
      return nil unless File.file?(contract_path)
      Dovetail::Contract.load_file(contract_path)
    end

    def compile_and_check(stdout:, stderr:)
      generated_dir = File.join(@out, "generated")
      @module_dirs = {}

      contract_paths = @config.contracts.dup
      panel_contract_of = {}
      @panel_dirs.each do |panel_dir|
        contract_path = File.expand_path(File.join(panel_dir, "..", "contract.rb"))
        next unless File.file?(contract_path)
        panel_contract_of[contract_path] = panel_dir
        contract_paths << contract_path unless contract_paths.include?(contract_path)
      end

      models = contract_paths.uniq.map { |p| Dovetail::Contract.load_file(p) }
      contract_paths.uniq.each_with_index do |contract_path, i|
        mod = models[i].to_h["module"]
        @module_dirs[mod] = panel_contract_of[contract_path] if panel_contract_of[contract_path]
      end

      findings = Dovetail::Contract.validate(models)
      @findings = { "contract" => findings.map { |f| f.to_h rescue { "rule" => f.rule, "message" => f.message } } }
      return unless findings.none? { |f| f.severity == "error" }

      Dovetail::Compiler.compile(models, out: generated_dir)

      panel_models = models.select { |m| @module_dirs.key?(m.to_h["module"]) }

      @shapes = {}
      panel_models.each do |m|
        mod = m.to_h["module"]
        shape_path = File.join(generated_dir, "shape", "#{mod}.shape.json")
        @shapes[mod] = JSON.parse(File.read(shape_path)) if File.file?(shape_path)
      end

      @findings["panels"] = {}
      @shapes.each do |mod, shape|
        report = Dovetail::Shape.check(panel_dir: @module_dirs[mod], shape: shape, profile: @config.rules_profile)
        @findings["panels"][mod] = report.to_h
      end

      generate_registry(panel_models, generated_dir)
      @models = panel_models
    end

    def generate_registry(models, generated_dir)
      layout = Dovetail::Layout.load(@config.layout)
      FileUtils.mkdir_p(File.join(@out, "bind"))
      models.each do |m|
        mod = m.to_h["module"]
        File.write(File.join(@out, "bind", "#{mod}.ts"), Dovetail::Fuse::Bind.generate(mod))
      end
      theme_infos = @config.themes.map { |p| { id: JSON.parse(File.read(p))["id"], path: p } }
      panel_infos = models.map do |m|
        mod = m.to_h["module"]
        entry_path = File.join(generated_dir, "registry", "#{mod}.json")
        entry = File.file?(entry_path) ? JSON.parse(File.read(entry_path)) : {}
        {
          module: mod,
          entry: entry,
          panel_svelte_path: File.join(@module_dirs[mod], "src", "Panel.svelte"),
          schema_path: File.join(generated_dir, "schema", "#{mod}.schema.json"),
          messages_paths: locale_messages(File.join(@module_dirs[mod], "messages"))
        }
      end
      registry_ts = Dovetail::Fuse::Registry.generate(
        panels: panel_infos,
        layout: layout,
        themes: theme_infos,
        shell_messages_paths: locale_messages(File.join(@config.shell, "messages")),
        development: true
      )
      File.write(File.join(@out, "registry.development.generated.ts"), registry_ts)
      vocabulary = Dovetail::Tokens.vocabulary
      File.write(File.join(@out, "app.css"), Dovetail::Fuse::Tailwind.entry_css(vocabulary, @panel_dirs, @config.shell))
    end

    def locale_messages(messages_dir)
      return {} unless Dir.exist?(messages_dir)
      Dir.glob(File.join(messages_dir, "*.json")).each_with_object({}) do |path, h|
        h[File.basename(path, ".json")] = path
      end
    end

    def write_findings
      FileUtils.mkdir_p(@out)
      File.write(File.join(@out, "dev-findings.json"), JSON.pretty_generate(@findings || {}))
    end

    def watch_paths
      files = []
      @panel_dirs.each do |d|
        files << File.expand_path(File.join(d, "..", "contract.rb"))
        files.concat(Dir.glob(File.join(d, "**", "*.{svelte,ts,js}")))
      end
      files
    end

    def start_watcher(stdout:)
      Thread.new do
        loop do
          sleep 1
          changed = false
          watch_paths.each do |f|
            next unless File.exist?(f)
            mtime = File.mtime(f).to_f
            if @mtimes[f] != mtime
              @mtimes[f] = mtime
              changed = true
            end
          end
          if changed
            compile_and_check(stdout: stdout, stderr: stdout)
            write_findings
            stdout.puts("dovetail: recompiled")
          end
        end
      end
    end

    def serve_vite(stdout:, stderr:)
      start_watcher(stdout: stdout)
      config_path = File.join(@out, "dev-config.json")
      config = {
        root: @config.shell,
        out: @out,
        panels: @panel_dirs.map { |d| { module: module_for(d).to_h["module"], dir: d } },
        backend: @backend,
        port: @port
      }
      File.write(config_path, JSON.generate(config))
      script = File.join(Dovetail.root, "runtime", "tools", "dev-server.mjs")
      pid = Process.spawn(@config.node.to_s, script, config_path, out: stdout, err: stderr)
      trap("INT") { Process.kill("TERM", pid) rescue nil }
      Process.wait(pid)
    end

    def serve_static(stdout:)
      require_relative "verify/static_server"
      require_relative "dev/static_page"
      theme_path = @config.themes.first
      theme = theme_path ? JSON.parse(File.read(theme_path)) : nil
      page_dir = Dir.mktmpdir("dovetail-dev-static")
      write_static_page(page_dir, theme)
      server = TCPServer.new("127.0.0.1", @port)
      stdout.puts("dovetail dev --static serving on http://127.0.0.1:#{@port}/")
      trap("INT") { server.close rescue nil; exit(0) }
      loop do
        client = server.accept
        write_static_page(page_dir, theme)
        body = File.read(File.join(page_dir, "index.html"))
        client.write("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
        client.write(body)
        client.close
      end
    end

    def write_static_page(dir, theme)
      File.write(File.join(dir, "index.html"), Dovetail::Dev::StaticPage.render(@findings || {}, theme))
    end
  end
end
