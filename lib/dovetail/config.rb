require "yaml"

module Dovetail
  class Config
    DEFAULT_CONTRACTS = "modules/*/contract.rb"
    DEFAULT_PANELS = "modules/*/panel"
    DEFAULT_SHELL = "ui"
    DEFAULT_OUT = ".dovetail"
    DEFAULT_RULES_PROFILE = "strict"
    DEFAULT_NODE = "node"
    DEFAULT_LIVE_BASE = "/live/"
    DEFAULT_EMBED_TAG = "dovetail-app"
    RESERVED_EMBED_TAGS = %w[
      annotation-xml color-profile font-face font-face-src font-face-uri font-face-format font-face-name missing-glyph
    ].freeze

    class << self
      def find(start_dir)
        dir = File.expand_path(start_dir)
        loop do
          candidate = File.join(dir, "dovetail.yml")
          return load(candidate) if File.file?(candidate)
          parent = File.dirname(dir)
          return nil if parent == dir
          dir = parent
        end
      end

      def load(path)
        path = File.expand_path(path)
        text = begin
          File.read(path)
        rescue StandardError => e
          raise Dovetail::Error.new("D-CFG-001", "could not read #{path}: #{e.message}")
        end
        raw = begin
          YAML.safe_load(text, permitted_classes: [], aliases: false)
        rescue StandardError => e
          raise Dovetail::Error.new("D-CFG-001", "#{path} is not valid YAML: #{e.message}")
        end
        raw = {} if raw.nil?
        unless raw.is_a?(Hash)
          raise Dovetail::Error.new("D-CFG-001", "#{path} must be a mapping")
        end
        new(File.dirname(path), raw)
      end
    end

    def initialize(root_dir, raw)
      @root = File.expand_path(root_dir)
      @raw = raw || {}
    end

    def root
      @root
    end

    def contracts
      pattern = @raw["contracts"] || DEFAULT_CONTRACTS
      Dir.glob(File.join(@root, pattern)).sort.map { |p| File.expand_path(p) }
    end

    def panels
      pattern = @raw["panels"] || DEFAULT_PANELS
      Dir.glob(File.join(@root, pattern)).sort.map { |p| File.expand_path(p) }
    end

    def shell
      File.expand_path(File.join(@root, @raw["shell"] || DEFAULT_SHELL))
    end

    def out
      File.expand_path(File.join(@root, @raw["out"] || DEFAULT_OUT))
    end

    def public_keys
      keys = @raw["public_keys"] || []
      keys.map { |k| File.expand_path(File.join(@root, k)) }
    end

    def require_signed
      value = @raw.key?("require_signed") ? @raw["require_signed"] : false
      value ? true : false
    end

    def rules_profile
      @raw["rules_profile"] || DEFAULT_RULES_PROFILE
    end

    def tokens
      value = @raw["tokens"]
      return nil if value.nil?
      File.expand_path(File.join(@root, value))
    end

    def layout
      value = @raw["layout"] || File.join(@raw["shell"] || DEFAULT_SHELL, "layout.yml")
      File.expand_path(File.join(@root, value))
    end

    def node
      return false if @raw.key?("node") && @raw["node"] == false
      @raw["node"] || DEFAULT_NODE
    end

    def themes
      pattern = @raw["themes"] || File.join(shell, "themes", "*.json")
      pattern = File.expand_path(pattern, @root)
      Dir.glob(pattern).sort.map { |p| File.expand_path(p) }
    end

    def live
      Array(@raw["live"]).map(&:to_s)
    end

    def live_base
      value = (@raw["live_base"] || DEFAULT_LIVE_BASE).to_s
      value = "/#{value}" unless value.start_with?("/")
      value = "#{value}/" unless value.end_with?("/")
      value
    end

    def embed
      @raw["embed"] == true
    end

    def embed_tag
      @raw["embed_tag"] || DEFAULT_EMBED_TAG
    end

    def validate_embed_tag!
      tag = embed_tag
      valid = tag.is_a?(String) &&
        tag.match?(/\A[a-z][a-z0-9-]*[a-z0-9]\z/) &&
        tag.include?("-") &&
        !tag.include?("--") &&
        !RESERVED_EMBED_TAGS.include?(tag)
      unless valid
        raise Dovetail::Error.new("D-CFG-001", "embed_tag #{tag} is not a valid custom element name")
      end
      tag
    end
  end
end
