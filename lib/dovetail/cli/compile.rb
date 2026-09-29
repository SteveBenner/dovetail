require "optparse"

module Dovetail
  module CLI
    module Compile
      module_function

      def run(args, stdout:, stderr:)
        out = nil
        parser = OptionParser.new do |o|
          o.on("--out DIR") { |v| out = v }
        end
        files = parser.parse(args)
        if out.nil? || files.empty?
          stderr.puts("dovetail compile: --out and at least one contract file are required")
          return 2
        end
        models = files.map { |f| Dovetail::Contract.load_file(f) }
        begin
          written = Dovetail::Compiler.compile(models, out: out)
        rescue Dovetail::Error => e
          if e.code == "D-CON-002"
            findings = e.details[:findings] || []
            error_findings = findings.select { |f| f.severity == "error" }
            failed_count = error_findings.map(&:module_id).uniq.length
            stderr.puts("D-CON-002 #{failed_count} contract(s) failed validation")
            error_findings.each do |f|
              stderr.puts("#{f.module_id}: #{f.rule} #{f.message}")
            end
            return 1
          end
          raise
        end
        unless Dovetail::CLI.quiet
          written.each { |w| stdout.puts(w) }
          stdout.puts("compiled #{models.length} contracts")
        end
        0
      end
    end
  end
end
