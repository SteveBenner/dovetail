require "json"

module Dovetail
  module CanonicalJSON
    module_function

    def sort(value)
      case value
      when Hash
        pairs = value.map { |key, item| [key.to_s, item] }
        pairs.sort_by { |pair| pair[0] }.each_with_object({}) { |pair, out| out[pair[0]] = sort(pair[1]) }
      when Array
        value.map { |item| sort(item) }
      when Symbol
        value.to_s
      else
        value
      end
    end

    def dump(value)
      JSON.generate(sort(value))
    end

    def pretty(value)
      "#{pretty_value(sort(value), 0)}\n"
    end

    def pretty_value(value, depth)
      case value
      when Hash
        return "{}" if value.empty?
        indent = "  " * (depth + 1)
        closing_indent = "  " * depth
        entries = value.map { |k, v| "#{indent}#{k.to_s.to_json}: #{pretty_value(v, depth + 1)}" }
        "{\n#{entries.join(",\n")}\n#{closing_indent}}"
      when Array
        return "[]" if value.empty?
        indent = "  " * (depth + 1)
        closing_indent = "  " * depth
        entries = value.map { |v| "#{indent}#{pretty_value(v, depth + 1)}" }
        "[\n#{entries.join(",\n")}\n#{closing_indent}]"
      else
        value.to_json
      end
    end
  end
end
