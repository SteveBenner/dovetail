require "optparse"

module Dovetail
  module CLI
    module Contract
      module_function

      def run(args, stdout:, stderr:)
        sub = args.shift
        case sub
        when "lint"
          lint(args, stdout: stdout, stderr: stderr)
        when "diff"
          diff(args, stdout: stdout, stderr: stderr)
        when "compat"
          compat(args, stdout: stdout, stderr: stderr)
        when "show"
          show(args, stdout: stdout, stderr: stderr)
        else
          stderr.puts("dovetail contract: unknown subcommand #{sub}")
          2
        end
      end

      def lint(args, stdout:, stderr:)
        models = args.map { |f| Dovetail::Contract.load_file(f) }
        findings = Dovetail::Contract.validate(models)
        has_error = findings.any? { |f| f.severity == "error" }
        if has_error
          failed_count = findings.select { |f| f.severity == "error" }.map(&:module_id).uniq.length
          stderr.puts("D-CON-002 #{failed_count} contract(s) failed validation")
        end
        findings.each do |f|
          stdout.puts("#{f.module_id}: #{f.rule} #{f.severity} #{f.message}")
        end
        if !has_error && !Dovetail::CLI.quiet
          args.each_with_index do |file, i|
            model = models[i]
            stdout.puts("#{file}: ok (#{model.module_id} v#{model.version})")
          end
        end
        has_error ? 1 : 0
      end

      def diff(args, stdout:, stderr:)
        format = "text"
        parser = OptionParser.new do |o|
          o.on("--format FORMAT") { |v| format = v }
        end
        files = parser.parse(args)
        unless files.length == 2
          stderr.puts("dovetail contract diff: needs exactly two files")
          return 2
        end
        old_model = Dovetail::Contract.load_file(files[0])
        new_model = Dovetail::Contract.load_file(files[1])
        changes = Dovetail::Contract.diff(old_model.to_h, new_model.to_h)
        if format == "json"
          stdout.puts(Dovetail::CanonicalJSON.pretty(changes.map { |c| { "kind" => c.kind.to_s, "description" => c.description } }))
        else
          changes.each { |c| stdout.puts("#{c.kind}: #{c.description}") }
        end
        if Dovetail::Contract.version_ok?(old_model.to_h, new_model.to_h, changes)
          0
        else
          stderr.puts("D-CON-003 breaking change without a version increase (still v#{new_model.version})")
          1
        end
      end

      def compat(args, stdout:, stderr:)
        format = "text"
        parser = OptionParser.new do |o|
          o.on("--format FORMAT") { |v| format = v }
        end
        files = parser.parse(args)
        unless files.length == 2
          stderr.puts("dovetail contract compat: needs exactly two files")
          return 2
        end
        old_model = Dovetail::Contract.load_file(files[0])
        new_model = Dovetail::Contract.load_file(files[1])
        result = Dovetail::Negotiation.compat(old_model.to_h, new_model.to_h)
        if format == "json"
          stdout.puts(Dovetail::CanonicalJSON.pretty(result))
        else
          { "operation" => result["operations"], "event" => result["events"] }.each do |label, verdicts|
            verdicts.keys.sort.each do |name|
              v = verdicts[name]
              if v["compatible"]
                stdout.puts("#{label} #{name}: compatible")
              else
                stdout.puts("#{label} #{name}: breaking (#{v["breaking"].join("; ")})")
              end
            end
          end
        end
        0
      end

      def show(args, stdout:, stderr:)
        file = args.first
        if file.nil?
          stderr.puts("dovetail contract show: a contract file is required")
          return 2
        end
        model = Dovetail::Contract.load_file(file)
        stdout.puts(Dovetail::CanonicalJSON.pretty(model.to_h))
        0
      end
    end
  end
end
