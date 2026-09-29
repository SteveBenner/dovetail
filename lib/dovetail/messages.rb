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

    def check(panel_dirs)
      findings = []
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
