module Dovetail
  module Contract
    module TypeRef
      module_function

      def build(raw)
        case raw
        when ScalarMarker
          { "kind" => "scalar", "name" => raw.name }
        when Composites::CompositeList
          { "kind" => "list", "of" => build(raw.of) }
        when Composites::CompositeMap
          { "kind" => "map", "of" => build(raw.of) }
        when Composites::CompositeOneOf
          { "kind" => "one_of", "names" => raw.names.map(&:to_s) }
        when Composites::CompositeRef
          { "kind" => "ref", "module" => raw.mod.to_s, "name" => raw.name.to_s }
        when Symbol
          { "kind" => "named", "name" => raw.to_s }
        when Hash
          {
            "kind" => "inline",
            "fields" => raw.map { |key, value| build_field(key, value, {}) }
          }
        else
          raise Dovetail::Error.new("D-CON-001", "invalid type expression #{raw.inspect}")
        end
      end

      def build_field(name, type_raw, options)
        has_default = options.key?(:default)
        required = options.key?(:required) ? !!options[:required] : !has_default
        {
          "name" => name.to_s,
          "type" => build(type_raw),
          "required" => required,
          "nullable" => !!options[:nullable],
          "description" => options[:description],
          "default" => has_default ? options[:default] : nil,
          "has_default" => has_default,
          "enum" => options[:enum] ? options[:enum].map { |e| e.is_a?(Symbol) ? e.to_s : e } : nil,
          "min" => options[:min],
          "max" => options[:max],
          "pattern" => options[:pattern],
          "format" => options[:format] ? options[:format].to_s : nil,
          "sensitive" => !!options[:sensitive],
          "deprecated" => options[:deprecated]
        }
      end
    end
  end
end
