require "yaml"

module Dovetail
  module Tokens
    module_function

    DEFAULT_PATH = File.expand_path("tokens/vocabulary.yml", __dir__)

    def vocabulary(path = nil)
      file = path || DEFAULT_PATH
      @cache ||= {}
      @cache[file] ||= YAML.safe_load(File.read(file), permitted_classes: [], aliases: false)
    end

    def css_var_name(pattern, token)
      pattern.sub("{token}", token.to_s.gsub(".", "_"))
    end

    def css_vars(path = nil)
      vocab = vocabulary(path)
      names = []
      vocab.fetch("families").each do |_family, data|
        pattern = data.fetch("css_var")
        tokens = data.fetch("tokens")
        tokens.each { |token| names << css_var_name(pattern, token) }
        if data["line_height_var"]
          tokens.each { |token| names << css_var_name(data["line_height_var"], token) }
        end
        Array(data["extra_vars"]).each { |v| names << v }
      end
      names
    end

    def host_vars(path = nil)
      Array(vocabulary(path)["host_vars"]).dup
    end

    def theme_keys(path = nil)
      (css_vars(path) + host_vars(path)).map { |name| name.sub(/\A--/, "") }
    end
  end
end

require_relative "tokens/class_grammar"
