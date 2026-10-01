require "optparse"
require "dovetail/messages"
require "dovetail/config"

module Dovetail
  module CLI
    module Messages
      class << self
        def run(args, stdout:, stderr:)
          app_dir = nil
          panel_dirs = []
          rest = args.dup
          sub = rest.shift
          unless sub == "check"
            raise Dovetail::Error.new("D-USE-001", "unknown subcommand #{sub.inspect}")
          end
          parser = OptionParser.new do |o|
            o.on("--app DIR") { |v| app_dir = v }
            o.on("--panels DIR", "repeatable") { |v| panel_dirs << v }
          end
          parser.parse!(rest)

          shell_dir = nil
          if panel_dirs.empty?
            config = Dovetail::Config.find(app_dir || Dir.pwd)
            unless config
              raise Dovetail::Error.new("D-CFG-001", "no dovetail.yml found and no --panels given")
            end
            panel_dirs = config.panels
            shell_dir = config.shell
          else
            panel_dirs = panel_dirs.map { |p| File.expand_path(p) }
            shell_dir = File.expand_path(app_dir) if app_dir
          end

          findings = Dovetail::Messages.check(panel_dirs, shell_dir: shell_dir)
          findings.each do |f|
            stdout.puts("#{f["panel"]}: #{f["locale"]} #{f["key"]} #{f["issue"]}") unless quiet?
          end
          findings.empty? ? 0 : 1
        end

        def quiet?
          Dovetail::CLI.quiet
        end
      end
    end
  end
end
