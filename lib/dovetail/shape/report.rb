module Dovetail
  module Shape
    class Report
      attr_reader :findings, :panel, :shape_version

      def initialize(panel:, shape_version:, findings:)
        @panel = panel
        @shape_version = shape_version
        @findings = findings.sort_by { |f| [f.file, f.line, f.column, f.rule] }
      end

      def errors
        findings.count { |f| f.severity == "error" }
      end

      def warnings
        findings.count { |f| f.severity == "warning" }
      end

      def to_h
        {
          "panel" => panel,
          "shape_version" => shape_version,
          "findings" => findings.map(&:to_h),
          "summary" => { "errors" => errors, "warnings" => warnings }
        }
      end
    end
  end
end
