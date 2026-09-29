module Dovetail
  module Shape
    Finding = Struct.new(:file, :line, :column, :rule, :seam, :severity, :message, :fix) do
      def to_h
        {
          "file" => file,
          "line" => line,
          "column" => column,
          "rule" => rule,
          "seam" => seam,
          "severity" => severity,
          "message" => message,
          "fix" => fix
        }
      end
    end
  end
end
