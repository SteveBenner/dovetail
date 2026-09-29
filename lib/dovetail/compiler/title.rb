module Dovetail
  module Compiler
    module Title
      module_function

      def for_module(module_id)
        module_id.to_s.split("_").map { |w| w.empty? ? w : w[0].upcase + w[1..-1].to_s }.join(" ")
      end

      def camel_case(module_id)
        parts = module_id.to_s.split("_")
        return "" if parts.empty?
        ([parts.first] + parts[1..-1].map { |w| w.empty? ? w : w[0].upcase + w[1..-1].to_s }).join
      end

      def pascal_case(module_id)
        module_id.to_s.split("_").map { |w| w.empty? ? w : w[0].upcase + w[1..-1].to_s }.join
      end
    end
  end
end
