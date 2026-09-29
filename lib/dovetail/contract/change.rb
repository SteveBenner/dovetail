module Dovetail
  module Contract
    class Change < Struct.new(:kind, :description, :subjects)
      def initialize(kind, description, subjects = nil)
        super(kind, description, subjects || [])
      end
    end
  end
end
