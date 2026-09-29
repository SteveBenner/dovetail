module Dovetail
  module Compiler
    module JsonSchema
      module_function

      SCALAR_BASE = {
        "String" => { "type" => "string" },
        "Integer" => { "type" => "integer" },
        "Boolean" => { "type" => "boolean" },
        "Date" => { "type" => "string", "format" => "date" },
        "DateTime" => { "type" => "string", "format" => "date-time" },
        "Url" => { "type" => "string", "format" => "uri" },
        "Email" => { "type" => "string", "format" => "email" }
      }.freeze

      def generate(model)
        defs = {}
        model.types.each do |name, type|
          defs[name] = object_schema(type["fields"], defs)
        end
        model.operations.each do |name, op|
          defs["operation.#{name}.input"] = type_ref_schema(op["input"], defs)
          defs["operation.#{name}.output"] = type_ref_schema(op["output"], defs)
        end
        model.emits.each do |name, event|
          defs["event.#{name}.payload"] = type_ref_schema(event["payload"], defs)
        end
        panel = model.panel
        if panel
          panel["storage_keys"].each do |sk|
            defs["storage.#{sk["name"]}"] = sk["type"] ? type_ref_schema(sk["type"], defs) : { "type" => "string" }
          end
          panel["props"].each do |p|
            defs["prop.#{p["name"]}"] = type_ref_schema(p["type"], defs)
          end
        end
        {
          "$schema" => "https://json-schema.org/draft/2020-12/schema",
          "$id" => "#{model.module_id}.schema.json",
          "title" => Title.for_module(model.module_id),
          "$defs" => defs
        }
      end

      def object_schema(fields, defs)
        properties = {}
        required = []
        fields.each do |f|
          properties[f["name"]] = field_schema(f, defs)
          required << f["name"] if f["required"] && !f["has_default"]
        end
        { "type" => "object", "additionalProperties" => false, "properties" => properties, "required" => required }
      end

      def field_schema(f, defs)
        base = type_ref_schema(f["type"], defs)
        base = apply_field_options(base, f)
        f["nullable"] ? { "anyOf" => [base, { "type" => "null" }] } : base
      end

      def type_ref_schema(type_ref, defs)
        case type_ref["kind"]
        when "scalar"
          scalar_schema(type_ref["name"], defs)
        when "named"
          { "$ref" => "#/$defs/#{type_ref["name"]}" }
        when "ref"
          { "$ref" => "#{type_ref["module"]}.schema.json#/$defs/#{type_ref["name"]}" }
        when "list"
          { "type" => "array", "items" => type_ref_schema(type_ref["of"], defs) }
        when "map"
          { "type" => "object", "additionalProperties" => type_ref_schema(type_ref["of"], defs) }
        when "one_of"
          {
            "oneOf" => type_ref["names"].map { |n| one_of_branch(n, defs) }
          }
        when "inline"
          object_schema(type_ref["fields"], defs)
        else
          {}
        end
      end

      def one_of_branch(name, defs)
        base = defs[name] || { "type" => "object", "additionalProperties" => false, "properties" => {}, "required" => [] }
        properties = base["properties"].merge("kind" => { "const" => name })
        required = (base["required"] + ["kind"]).uniq
        { "type" => "object", "additionalProperties" => false, "properties" => properties, "required" => required }
      end

      def scalar_schema(name, defs)
        case name
        when "Decimal"
          defs["_Decimal"] ||= { "type" => "string", "pattern" => "^-?[0-9]+(\\.[0-9]+)?$" }
          { "$ref" => "#/$defs/_Decimal" }
        when "Percent"
          defs["_Percent"] ||= { "type" => "string", "pattern" => "^-?[0-9]+(\\.[0-9]+)?$" }
          { "$ref" => "#/$defs/_Percent" }
        when "Id"
          defs["_Id"] ||= { "type" => "string", "minLength" => 1 }
          { "$ref" => "#/$defs/_Id" }
        when "Money"
          defs["_CurrencyCode"] ||= { "type" => "string", "pattern" => "^[A-Z]{3}$" }
          defs["_Money"] ||= {
            "type" => "object",
            "required" => %w[amount currency],
            "additionalProperties" => false,
            "properties" => {
              "amount" => { "$ref" => "#/$defs/_Decimal" },
              "currency" => { "$ref" => "#/$defs/_CurrencyCode" }
            }
          }
          defs["_Decimal"] ||= { "type" => "string", "pattern" => "^-?[0-9]+(\\.[0-9]+)?$" }
          { "$ref" => "#/$defs/_Money" }
        else
          SCALAR_BASE.fetch(name, { "type" => "string" })
        end
      end

      def apply_field_options(schema, f)
        out = schema.dup
        out["description"] = f["description"] if f["description"]
        out["default"] = f["default"] if f["has_default"]
        out["enum"] = f["enum"] if f["enum"]
        if f["min"] || f["max"]
          keys = min_max_keys(f["type"])
          out[keys[:min]] = f["min"] if f["min"]
          out[keys[:max]] = f["max"] if f["max"]
        end
        out["pattern"] = f["pattern"] if f["pattern"]
        apply_format!(out, f["format"]) if f["format"]
        out["x-dovetail-sensitive"] = true if f["sensitive"]
        if f["deprecated"]
          out["deprecated"] = true
          out["x-dovetail-replacement"] = f["deprecated"]
        end
        out
      end

      def min_max_keys(type_ref)
        kind = type_ref["kind"]
        name = type_ref["name"]
        if kind == "list"
          { min: "minItems", max: "maxItems" }
        elsif kind == "scalar" && name == "Integer"
          { min: "minimum", max: "maximum" }
        elsif kind == "scalar" && %w[String Url Email].include?(name)
          { min: "minLength", max: "maxLength" }
        elsif kind == "scalar" && %w[Decimal Percent Money].include?(name)
          { min: "x-dovetail-min", max: "x-dovetail-max" }
        else
          { min: "minimum", max: "maximum" }
        end
      end

      def apply_format!(out, format)
        case format
        when "iso_date" then out["format"] = "date"
        when "iso_datetime" then out["format"] = "date-time"
        when "currency_code" then out["pattern"] = "^[A-Z]{3}$"
        when "locale" then out["pattern"] = "^[a-z]{2,3}(-[A-Z]{2})?$"
        when "country_code" then out["pattern"] = "^[A-Z]{2}$"
        when "sha256" then out["pattern"] = "^[0-9a-f]{64}$"
        end
      end
    end
  end
end
