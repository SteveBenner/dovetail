require "yaml"

module Dovetail
  module Shape
    module RuleCatalog
      DEFAULT_PATH = File.expand_path("rules.yml", __dir__)

      module_function

      def rules(path = nil)
        file = path || DEFAULT_PATH
        @cache ||= {}
        @cache[file] ||= YAML.safe_load(File.read(file), permitted_classes: [], aliases: false).fetch("rules")
      end

      def by_id(path = nil)
        rules(path).each_with_object({}) { |r, h| h[r["id"]] = r }
      end

      def severity_for(rule, profile)
        if profile == "relaxed" && rule["relaxed_severity"]
          rule["relaxed_severity"]
        else
          rule["severity"]
        end
      end
    end
  end
end
