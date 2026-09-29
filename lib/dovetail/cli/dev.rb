require "optparse"
require "dovetail/dev"

module Dovetail
  module CLI
    module Dev
      class << self
        def run(args, stdout:, stderr:)
          app = nil
          panels = []
          backend = nil
          static = false
          port = 5173
          OptionParser.new do |o|
            o.on("--app DIR") { |v| app = v }
            o.on("--panels DIR") { |v| panels << v }
            o.on("--backend URL") { |v| backend = v }
            o.on("--static") { static = true }
            o.on("--port N", Integer) { |v| port = v }
          end.parse!(args)

          unless app
            raise Dovetail::Error.new("D-USE-001", "--app is required")
          end

          begin
            Dovetail::Dev.new(app: app, panel_dirs: panels, backend: backend, static: static, port: port).run(stdout: stdout, stderr: stderr)
          rescue Dovetail::Error => e
            stderr.puts("#{e.code} #{e.message}")
            2
          end
        end
      end
    end
  end
end
