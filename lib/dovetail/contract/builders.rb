module Dovetail
  module Contract
    class TypeBuilder
      include Composites

      def initialize
        @fields = []
      end

      attr_reader :fields

      def field(name, type_raw, **options)
        Naming.check!(name)
        loc = caller_locations(1, 1)&.first
        Validation.check_field_options!(name, options, location: loc)
        Validation.check_format!(name, options[:format], location: loc)
        @fields << TypeRef.build_field(name, type_raw, options)
      end
    end

    class PanelBuilder
      include Composites

      REQUIRED_STATES = %w[loading empty error unavailable ready].freeze
      BLOCKING_DEFAULT = { "modal" => true, "drawer" => true, "popover" => false, "menu" => false, "toast" => false }.freeze

      def initialize
        @slots = []
        @views = []
        @capabilities = []
        @routes = []
        @props = []
        @tokens = ["default"]
        @storage_keys = []
        @shortcuts = []
        @overlays = []
      end

      def slot(name, size:, min_width: nil, max_width: nil, description: nil)
        Naming.check!(name)
        loc = caller_locations(1, 1)&.first
        Validation.check_included!("slot #{name}", "size", size, Validation::SLOT_SIZES, location: loc)
        Validation.check_positive_integer!("slot #{name}", "min_width", min_width, location: loc)
        Validation.check_positive_integer!("slot #{name}", "max_width", max_width, location: loc)
        @slots << {
          "name" => name.to_s,
          "size" => size.to_s,
          "min_width" => min_width,
          "max_width" => max_width,
          "description" => description
        }
      end

      def view(name, data:, states: REQUIRED_STATES.map(&:to_sym), description: nil)
        Naming.check!(name)
        @views << {
          "name" => name.to_s,
          "data" => data.to_s,
          "states" => states.map(&:to_s),
          "description" => description
        }
      end

      def capability(name, **_options)
        Naming.check!(name)
        loc = caller_locations(1, 1)&.first
        Validation.check_included!("capability", "capability", name, Validation::CAPABILITIES, location: loc)
        @capabilities << name.to_s
      end

      def route(pattern)
        @routes << pattern
      end

      def prop(name, type_raw, required: true)
        Naming.check!(name)
        @props << {
          "name" => name.to_s,
          "type" => TypeRef.build(type_raw),
          "required" => !!required
        }
      end

      def tokens(value)
        if value == :default
          @tokens = ["default"]
        else
          loc = caller_locations(1, 1)&.first
          Array(value).each { |family| Validation.check_included!("tokens", "family", family, Validation::TOKEN_FAMILIES, location: loc) }
          @tokens = Array(value).map(&:to_s)
        end
      end

      def storage_key(name, type: nil, ttl_days: nil)
        Naming.check!(name)
        Validation.check_positive_integer!("storage_key #{name}", "ttl_days", ttl_days, location: caller_locations(1, 1)&.first)
        @storage_keys << {
          "name" => name.to_s,
          "type" => type.nil? ? nil : TypeRef.build(type),
          "ttl_days" => ttl_days
        }
      end

      def shortcut(keys, action:, scope: :panel)
        Naming.check!(action)
        Validation.check_included!("shortcut '#{keys}'", "scope", scope, Validation::SHORTCUT_SCOPES, location: caller_locations(1, 1)&.first)
        @shortcuts << {
          "keys" => keys,
          "action" => action.to_s,
          "scope" => scope.to_s
        }
      end

      def overlay(name, kind:, dismissible: true, blocking: nil, description: nil)
        Naming.check!(name)
        Validation.check_included!("overlay #{name}", "kind", kind, Validation::OVERLAY_KINDS, location: caller_locations(1, 1)&.first)
        resolved_blocking = blocking.nil? ? BLOCKING_DEFAULT.fetch(kind.to_s, false) : !!blocking
        @overlays << {
          "name" => name.to_s,
          "kind" => kind.to_s,
          "dismissible" => !!dismissible,
          "blocking" => resolved_blocking,
          "description" => description
        }
      end

      def to_h
        {
          "slots" => @slots,
          "views" => @views,
          "capabilities" => @capabilities,
          "routes" => @routes,
          "props" => @props,
          "tokens" => @tokens,
          "storage_keys" => @storage_keys,
          "shortcuts" => @shortcuts,
          "overlays" => @overlays
        }
      end
    end

    class ContractBuilder
      include Composites

      def initialize(module_id, version, description)
        Naming.check!(module_id)
        @module_id = module_id
        @version = version
        @description = description
        @types = {}
        @operations = {}
        @emits = {}
        @consumes = []
        @depends_on = []
        @panel = nil
        @seen_type_names = []
        @seen_operation_names = []
        @seen_event_names = []
      end

      def type(name, &block)
        Naming.check!(name)
        @seen_type_names << name.to_s
        builder = TypeBuilder.new
        builder.instance_eval(&block) if block
        @types[name.to_s] = { "fields" => builder.fields }
      end

      def operation(name, input: nil, output: nil, errors: [], timeout_ms: 10000, idempotent: false, description: nil)
        Naming.check!(name)
        raise Dovetail::Error.new("D-CON-001", "operation '#{name}' needs an output") if output.nil?
        Validation.check_positive_integer!("operation #{name}", "timeout_ms", timeout_ms, location: caller_locations(1, 1)&.first)
        @seen_operation_names << name.to_s
        @operations[name.to_s] = {
          "input" => TypeRef.build(input.nil? ? {} : input),
          "output" => TypeRef.build(output),
          "errors" => errors.map(&:to_s),
          "timeout_ms" => timeout_ms,
          "idempotent" => !!idempotent,
          "description" => description
        }
      end

      def emits(name, payload: {}, description: nil)
        Naming.check!(name)
        @seen_event_names << name.to_s
        @emits[name.to_s] = {
          "payload" => TypeRef.build(payload),
          "description" => description
        }
      end

      def consumes(module_id, event)
        Naming.check!(module_id)
        Naming.check!(event)
        @consumes << { "module" => module_id.to_s, "event" => event.to_s }
      end

      def depends_on(module_id, version: ">= 1")
        Naming.check!(module_id)
        @depends_on << { "module" => module_id.to_s, "requirement" => version }
      end

      def panel(&block)
        builder = PanelBuilder.new
        builder.instance_eval(&block) if block
        @panel = builder.to_h
      end

      def to_model_hash
        {
          "schema" => "dovetail.model/v1",
          "module" => @module_id.to_s,
          "version" => @version,
          "description" => @description,
          "depends_on" => @depends_on,
          "types" => @types,
          "operations" => @operations,
          "emits" => @emits,
          "consumes" => @consumes,
          "panel" => @panel
        }
      end

      def duplicates
        {
          "type" => duplicate_names(@seen_type_names),
          "operation" => duplicate_names(@seen_operation_names),
          "event" => duplicate_names(@seen_event_names)
        }
      end

      private

      def duplicate_names(names)
        names.group_by { |n| n }.select { |_, v| v.length > 1 }.keys
      end
    end
  end
end
