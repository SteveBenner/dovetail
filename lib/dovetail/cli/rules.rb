require_relative "../shape/rule_catalog"

module Dovetail
  module CLI
    module Rules
      module_function

      def run(args, stdout:, stderr:)
        rules = Dovetail::Shape::RuleCatalog.rules
        id = args.first
        if id.nil?
          rules.each do |r|
            stdout.puts("#{r['id']}  #{r['seam']}  #{r['severity']}  #{r['finds']}")
          end
          return 0
        end
        rule = rules.find { |r| r["id"] == id }
        unless rule
          stderr.puts("dovetail: unknown rule #{id}")
          return 1
        end
        stdout.puts("id: #{rule['id']}")
        stdout.puts("seam: #{rule['seam']}")
        stdout.puts("severity: #{rule['severity']}")
        stdout.puts("relaxed_severity: #{rule['relaxed_severity']}") if rule["relaxed_severity"]
        stdout.puts("finds: #{rule['finds']}")
        stdout.puts("fix: #{rule['fix']}")
        stdout.puts("example_violation: #{rule['example_violation']}")
        stdout.puts("example_compliant: #{rule['example_compliant']}")
        stdout.puts("why_it_breaks_fusion: #{rule['why_it_breaks_fusion']}")
        0
      end
    end
  end
end
