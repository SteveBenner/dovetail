module Dovetail
  module Contract
    module Validation
      FIELD_OPTIONS = %i[required nullable default description enum min max pattern format sensitive deprecated].freeze
      FORMATS = %i[iso_date iso_datetime currency_code locale country_code sha256].freeze
      SLOT_SIZES = %i[full main aside tile strip].freeze
      OVERLAY_KINDS = %i[modal drawer popover menu toast].freeze
      CAPABILITIES = %i[overlay navigation storage keyboard lifecycle].freeze
      SHORTCUT_SCOPES = %i[panel view].freeze
      TOKEN_FAMILIES = %i[color space radius type weight shadow motion layout].freeze

      module_function

      def prefix(location, message)
        return message unless location
        "#{location.path}:#{location.lineno}: #{message}"
      end

      def check_included!(statement, field, value, allowed, location: nil)
        return if allowed.include?(value)
        raise Dovetail::Error.new("D-CON-001", prefix(location, "#{statement}: unknown #{field} #{value.inspect} (allowed: #{allowed.join(", ")})"))
      end

      def check_positive_integer!(statement, field, value, location: nil)
        return if value.nil?
        return if value.is_a?(Integer) && value > 0
        raise Dovetail::Error.new("D-CON-001", prefix(location, "#{statement}: #{field} must be a positive Integer (got #{value.inspect})"))
      end

      def check_field_options!(name, options, location: nil)
        unknown = options.keys - FIELD_OPTIONS
        return if unknown.empty?
        raise Dovetail::Error.new("D-CON-001", prefix(location, "field #{name}: unknown option #{unknown.first.inspect} (allowed: #{FIELD_OPTIONS.join(", ")})"))
      end

      def check_format!(name, format, location: nil)
        return if format.nil?
        check_included!("field #{name}", "format", format, FORMATS, location: location)
      end
    end
  end
end
