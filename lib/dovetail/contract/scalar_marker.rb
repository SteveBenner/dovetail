module Dovetail
  module Contract
    class ScalarMarker
      SCALARS = %w[String Integer Decimal Boolean Date DateTime Id Money Percent Url Email].freeze

      attr_reader :name

      def initialize(name)
        @name = name
      end

      INSTANCES = SCALARS.each_with_object({}) { |n, h| h[n] = new(n) }.freeze

      def self.for(name)
        INSTANCES[name]
      end
    end
  end
end
