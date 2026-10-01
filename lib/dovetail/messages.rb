require "json"

module Dovetail
  module Messages
    module_function

    def module_id_for(panel_dir)
      contract_path = File.expand_path(File.join(panel_dir, "..", "contract.rb"))
      return nil unless File.file?(contract_path)
      model = Dovetail::Contract.load_file(contract_path)
      model.to_h["module"].to_s
    rescue StandardError
      nil
    end

    def runtime_keys
      JSON.parse(File.read(File.join(Dovetail.root, "runtime", "src", "i18n", "messages", "en-US.json"))).keys
    end

    def locales_in(dir)
      return [] unless Dir.exist?(dir)
      Dir.glob(File.join(dir, "*.json")).map { |path| File.basename(path, ".json") }
    end

    def check_shell(shell_dir, panel_dirs)
      messages_dir = File.join(shell_dir, "messages")
      locales = (locales_in(messages_dir) + panel_dirs.flat_map { |dir| locales_in(File.join(dir, "messages")) }).uniq.sort - ["en-US"]
      keys = runtime_keys
      locales.flat_map do |locale|
        path = File.join(messages_dir, "#{locale}.json")
        present = File.file?(path) ? JSON.parse(File.read(path)).keys : []
        (keys - present).map do |key|
          { "panel" => shell_dir, "locale" => locale, "key" => key, "issue" => "missing_runtime_key" }
        end
      end
    end

    def check(panel_dirs, shell_dir: nil)
      findings = shell_dir ? check_shell(shell_dir, panel_dirs) : []
      panel_dirs.each do |panel_dir|
        messages_dir = File.join(panel_dir, "messages")
        next unless Dir.exist?(messages_dir)
        base_path = File.join(messages_dir, "en-US.json")
        next unless File.file?(base_path)
        base_keys = JSON.parse(File.read(base_path)).keys
        module_id = module_id_for(panel_dir)
        base_keys.each do |key|
          if module_id && !key.start_with?("#{module_id}.")
            findings << {
              "panel" => panel_dir,
              "locale" => "en-US",
              "key" => key,
              "issue" => "missing_prefix"
            }
          end
        end
        Dir.glob(File.join(messages_dir, "*.json")).sort.each do |locale_path|
          locale = File.basename(locale_path, ".json")
          next if locale == "en-US"
          locale_keys = JSON.parse(File.read(locale_path)).keys
          missing = base_keys - locale_keys
          missing.each do |key|
            findings << {
              "panel" => panel_dir,
              "locale" => locale,
              "key" => key,
              "issue" => "missing_key"
            }
          end
        end
      end
      findings
    end
  end
end
