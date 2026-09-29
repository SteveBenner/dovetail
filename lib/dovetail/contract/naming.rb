module Dovetail
  module Contract
    module Naming
      PATTERN = /\A[a-z][a-z0-9_]*\z/.freeze

      module_function

      def check!(value)
        text = value.to_s
        unless text =~ PATTERN
          raise Dovetail::Error.new("D-CON-001", "'#{text}' must be a lower snake case name")
        end
        text
      end
    end
  end
end
