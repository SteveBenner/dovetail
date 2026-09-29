require "json"

module Dovetail
  class Fuse
    module Registry
      module_function

      def js_identifier(module_id)
        module_id.to_s.split("_").map { |w| w[0].upcase + w[1..-1].to_s }.join("") + "Panel"
      end

      def js_string(value)
        JSON.generate(value.to_s)
      end

      def locale_var(prefix, locale)
        "#{prefix}Messages_#{locale.gsub(/[^a-zA-Z0-9]/, "_")}"
      end

      def messages_import_block(imports, prefix, messages_paths)
        (messages_paths || {}).map do |locale, path|
          var = locale_var(prefix, locale)
          imports << "import #{var} from #{js_string(path)};"
          [locale, var]
        end.to_h
      end

      def messages_object(vars_by_locale)
        "{ " + vars_by_locale.map { |locale, var| "#{js_string(locale)}: #{var}" }.join(", ") + " }"
      end

      def generate(panels:, layout:, themes:, shell_messages_paths:, development: false)
        imports = []
        panel_entries = []
        schema_entries = []

        theme_vars = themes.map.with_index do |theme, i|
          var_name = "theme#{i}_#{theme[:id].gsub("-", "_")}"
          imports << "import #{var_name} from #{js_string(theme[:path])};"
          var_name
        end

        shell_messages_vars = messages_import_block(imports, "shell", shell_messages_paths)

        panels.each do |p|
          component_var = js_identifier(p[:module])
          schema_var = "#{p[:module]}Schema"
          imports << "import #{component_var} from #{js_string(p[:panel_svelte_path])};"
          imports << "import #{schema_var} from #{js_string(p[:schema_path])};"
          panel_messages_vars = messages_import_block(imports, p[:module], p[:messages_paths])
          entry = p[:entry]
          fields = []
          fields << "module: #{js_string(entry["module"])}"
          fields << "title: #{js_string(entry["title"])}"
          fields << "contract_version: #{entry["contract_version"]}"
          fields << "component: #{component_var}"
          fields << "slots: #{JSON.generate(entry["slots"] || [])}"
          fields << "routes: #{JSON.generate(entry["routes"] || [])}"
          fields << "overlays: #{JSON.generate(entry["overlays"] || [])}"
          fields << "shortcuts: #{JSON.generate(entry["shortcuts"] || [])}"
          fields << "storage_keys: #{JSON.generate(entry["storage_keys"] || [])}"
          fields << "emits: #{JSON.generate(entry["emits"] || [])}"
          fields << "consumes: #{JSON.generate(entry["consumes"] || [])}"
          fields << "operations: #{JSON.generate(entry["operations"] || [])}"
          fields << "prefetch: #{JSON.generate(entry["prefetch"] || [])}"
          fields << "views: #{JSON.generate(entry["views"] || [])}"
          fields << "props: #{JSON.generate(entry["props"] || [])}"
          fields << "messages: #{messages_object(panel_messages_vars)}"
          panel_entries << "{ " + fields.join(", ") + " }"
          schema_entries << "  #{p[:module]}: #{schema_var},"
        end

        layout_json = JSON.generate({
          "slots" => layout.slots,
          "navigation" => layout.navigation,
          "breakpoints" => layout.breakpoints,
          "home" => layout.home
        })

        out = []
        out << "import type { Registry } from '@dovetail/runtime/internal';"
        out.concat(imports)
        out << ""
        out << "export const registry: Registry = {"
        out << "  schema: 'dovetail.registry/v1',"
        out << "  development: #{development ? "true" : "false"},"
        out << "  layout: #{layout_json},"
        out << "  themes: [#{theme_vars.join(", ")}],"
        out << "  panels: [#{panel_entries.join(", ")}],"
        out << "  schemas: {"
        out.concat(schema_entries)
        out << "  },"
        out << "  messages: #{messages_object(shell_messages_vars)},"
        out << "};"
        out << ""
        out << "export default registry;"
        out.join("\n") + "\n"
      end
    end
  end
end
