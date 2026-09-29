module Dovetail
  module Contract
    class Model
      def initialize(hash, duplicates = {})
        @hash = Model.freeze_deeply(hash)
        @duplicates = Model.freeze_deeply(duplicates)
      end

      def duplicates
        @duplicates
      end

      def to_h
        @hash
      end

      def module_id
        @hash["module"]
      end

      def version
        @hash["version"]
      end

      def panel
        @hash["panel"]
      end

      def types
        @hash["types"]
      end

      def operations
        @hash["operations"]
      end

      def emits
        @hash["emits"]
      end

      def consumes
        @hash["consumes"]
      end

      def depends_on
        @hash["depends_on"]
      end

      def self.freeze_deeply(value)
        case value
        when Hash
          value.each_value { |v| freeze_deeply(v) }
          value.freeze
        when Array
          value.each { |v| freeze_deeply(v) }
          value.freeze
        else
          begin
            value.freeze
          rescue TypeError
            value
          end
        end
      end
    end
  end
end
