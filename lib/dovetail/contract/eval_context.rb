module Dovetail
  module Contract
    class DovetailEntry
      def initialize
        @count = 0
        @model_hash = nil
        @builder = nil
      end

      attr_reader :model_hash, :builder

      def contract(module_id, version:, description: nil, &block)
        @count += 1
        if @count > 1
          raise Dovetail::Error.new("D-CON-001", "a file must declare exactly one contract")
        end
        @builder = ContractBuilder.new(module_id, version, description)
        @builder.instance_eval(&block) if block
        @model_hash = @builder.to_model_hash
      end

      def declared?
        @count == 1
      end
    end

    module EvalContext
      module_function

      def build(entry)
        klass = Class.new(BasicObject) do
          define_method(:require) do |name|
            unless name == "dovetail"
              Kernel.raise Dovetail::Error.new("D-CON-001", "require accepts only \"dovetail\"")
            end
            nil
          end

          define_method(:method_missing) do |name, *_args, **_kwargs|
            Kernel.raise Dovetail::Error.new("D-CON-001", "the method '#{name}' is not allowed in a contract file")
          end

          define_method(:respond_to_missing?) do |_name, _include_private|
            false
          end
        end
        klass.define_singleton_method(:const_missing) do |name|
          text = name.to_s
          if ScalarMarker::SCALARS.include?(text)
            ScalarMarker.for(text)
          elsif text == "Dovetail"
            entry
          else
            raise Dovetail::Error.new("D-CON-001", "the constant #{text} is not allowed in a contract file")
          end
        end
        klass.new
      end
    end
  end
end
