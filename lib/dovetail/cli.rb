require "optparse"

module Dovetail
  module CLI
    COMMANDS = {
      "compile" => ["dovetail/cli/compile", "Compile"],
      "check" => ["dovetail/cli/check", "Check"],
      "fuse" => ["dovetail/cli/fuse", "Fuse"],
      "verify" => ["dovetail/cli/verify", "Verify"],
      "contract" => ["dovetail/cli/contract", "Contract"],
      "brief" => ["dovetail/cli/brief", "Brief"],
      "sign" => ["dovetail/cli/sign", "Sign"],
      "new" => ["dovetail/cli/new", "New"],
      "rules" => ["dovetail/cli/rules", "Rules"],
      "dev" => ["dovetail/cli/dev", "Dev"],
      "messages" => ["dovetail/cli/messages", "Messages"],
      "checker" => ["dovetail/cli/checker", "Checker"]
    }.freeze

    USAGE = <<~TEXT.freeze
      Usage: dovetail <command> [options]

        compile <contract.rb>... --out <dir>
        check [<panel_dir>] --shape <file> | <shape.json> [--require-signed] [--public-key <pem>]... [--profile strict|relaxed] [--changed <file>] [--format text|json]
        fuse --app <shell> [--panels <dir>...] [--out <dir>] [--verify] [--development] [--live <glob>...]
        verify [<out>]
        contract lint|diff|compat|show <file>...
        brief <shape.json>
        sign <shape.json> --private-key <pem>
        new shell|panel <name>
        rules [id]
        dev --app <shell> [--panels <dir>...] [--backend <url>] [--static] [--port <n>]
        messages check [--app <shell>] [--panels <dir>...]
        checker export <dir>

      Global flags: --quiet --no-color --version
    TEXT

    class << self
      attr_accessor :quiet, :color

      def run(argv, stdout: $stdout, stderr: $stderr)
        args = argv.dup
        self.quiet = !args.delete("--quiet").nil?
        no_color = !args.delete("--no-color").nil?
        self.color = !no_color && ENV["NO_COLOR"].to_s.empty? && stdout.respond_to?(:tty?) && stdout.tty?
        if args.delete("--version")
          stdout.puts("dovetail #{Dovetail::VERSION}")
          return 0
        end
        name = args.shift
        if name.nil?
          stderr.puts(USAGE)
          return 2
        end
        if %w[help --help -h].include?(name)
          stdout.puts(USAGE)
          return 0
        end
        if args.include?("--help") || args.include?("-h")
          line = usage_line_for(name)
          if line
            stdout.puts("Usage: dovetail #{line}")
            return 0
          end
        end
        entry = COMMANDS[name]
        unless entry
          stderr.puts("dovetail: unknown command #{name}")
          stderr.puts(USAGE)
          return 2
        end
        require entry[0]
        const_get(entry[1]).run(args, stdout: stdout, stderr: stderr)
      rescue Dovetail::Error => e
        stderr.puts("#{e.code} #{e.message}")
        2
      rescue OptionParser::ParseError, SystemCallError => e
        stderr.puts("D-USE-001 #{e.message}")
        line = usage_line_for(name)
        stderr.puts("Usage: dovetail #{line}") if line
        2
      end

      def usage_line_for(name)
        return nil if name.nil?
        USAGE.each_line.map(&:strip).find { |line| line.split(" ", 2).first == name }
      end
    end
  end
end
