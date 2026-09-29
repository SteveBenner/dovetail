require "dovetail/verify"
require "dovetail/config"

module Dovetail
  module CLI
    module Verify
      class << self
        def run(args, stdout:, stderr:)
          out = args.shift
          if out
            out = File.expand_path(out)
          else
            config = Dovetail::Config.find(Dir.pwd)
            unless config
              raise Dovetail::Error.new("D-CFG-001", "no dovetail.yml found above #{Dir.pwd}")
            end
            out = config.out
          end
          build_dir = File.join(out, "verify-build")
          screenshots_dir = File.join(out, "screenshots")
          begin
            result = Dovetail::Verify.run(build_dir: build_dir, screenshots_dir: screenshots_dir)
            if result["ok"]
              stdout.puts("verify passed") unless Dovetail::CLI.quiet
              0
            else
              result["journeys"].each { |j| stdout.puts("#{j["code"]} #{j["journey"]} #{j["panel"]}: #{j["message"]}") }
              1
            end
          rescue Dovetail::Error => e
            stderr.puts("#{e.code} #{e.message}")
            2
          end
        end
      end
    end
  end
end
