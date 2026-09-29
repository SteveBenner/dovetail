require "json"

module Dovetail
  class Dev
    module StaticPage
      module_function

      def render(findings, theme)
        tokens = (theme && theme["tokens"]) || {}
        style_vars = tokens.map { |k, v| "--#{k}: #{v};" }.join(" ")
        panels = findings["panels"] || {}
        rows = panels.map do |mod, report|
          items = (report["findings"] || []).map do |f|
            "<li>#{escape(f["file"])}:#{f["line"]} #{escape(f["rule"])} #{escape(f["message"])}</li>"
          end.join
          "<section><h2>#{escape(mod)}</h2><ul>#{items}</ul></section>"
        end.join

        head = "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\" />" \
          "<meta http-equiv=\"refresh\" content=\"2\" /><title>Dovetail findings</title>" \
          "<style>:root { #{style_vars} } " \
          "body { background: var(--surface, #fff); color: var(--text, #111); font-family: var(--family-sans, sans-serif); margin: 0; padding: var(--space-6, 24px); } " \
          "h1 { font-size: var(--type-xl, 20px); } h2 { font-size: var(--type-base, 16px); } ul { padding-left: var(--space-4, 16px); }" \
          "</style></head>"
        body = "<body><h1>Dovetail findings</h1>" + rows + "</body></html>"
        head + body
      end

      def escape(value)
        value.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end
  end
end
