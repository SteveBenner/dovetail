require "optparse"
require "dovetail/fuse"

module Dovetail
  module CLI
    module Fuse
      class << self
        def run(args, stdout:, stderr:)
          app = nil
          panels = []
          verify = false
          out = nil
          development = false
          live = []
          OptionParser.new do |o|
            o.on("--app DIR") { |v| app = v }
            o.on("--panels DIR") { |v| panels << v }
            o.on("--verify") { verify = true }
            o.on("--out DIR") { |v| out = v }
            o.on("--development") { development = true }
            o.on("--live GLOB") { |v| live << v }
          end.parse!(args)

          unless app
            raise Dovetail::Error.new("D-USE-001", "--app is required")
          end

          begin
            report = Dovetail::Fuse.run(app: app, panel_dirs: panels, verify: verify, out: out, development: development, live: live)
            stdout.puts("fused #{report["panels"].length} panels") unless Dovetail::CLI.quiet
            0
          rescue Dovetail::Error => e
            stderr.puts("#{e.code} #{e.message}")
            case e.code
            when "D-CON-002", "D-CON-003", "D-FUS-001", "D-FUS-002", "D-FUS-003", "D-FUS-004", "D-TOK-001", "D-VER-001"
              1
            else
              2
            end
          end
        end
      end
    end
  end
end
