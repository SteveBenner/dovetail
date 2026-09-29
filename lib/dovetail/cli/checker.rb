require_relative "../checker_export"

module Dovetail
  module CLI
    module Checker
      module_function

      def run(args, stdout:, stderr:)
        sub = args.shift
        unless sub == "export"
          raise Dovetail::Error.new("D-USE-001", "dovetail checker takes one subcommand: export <dir>")
        end
        dir = args.shift
        if dir.nil? || dir.start_with?("-") || !args.empty?
          raise Dovetail::Error.new("D-USE-001", "checker export takes exactly one argument, <dir>")
        end
        Dovetail::CheckerExport.export(dir)
        stdout.puts("exported dovetail #{Dovetail::VERSION} checker to #{dir}") unless Dovetail::CLI.quiet
        0
      end
    end
  end
end
