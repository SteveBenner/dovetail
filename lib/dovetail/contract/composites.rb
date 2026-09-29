module Dovetail
  module Contract
    module Composites
      CompositeList = Struct.new(:of)
      CompositeMap = Struct.new(:of)
      CompositeOneOf = Struct.new(:names)
      CompositeRef = Struct.new(:mod, :name)

      def list(type)
        Composites::CompositeList.new(type)
      end

      def map(_key_type, type)
        Composites::CompositeMap.new(type)
      end

      def one_of(*names)
        Composites::CompositeOneOf.new(names)
      end

      def ref(mod, name)
        Composites::CompositeRef.new(mod, name)
      end
    end
  end
end
