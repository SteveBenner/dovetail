require "yaml"

module Dovetail
  class Layout
    VALID_SIZES = %w[full main aside tile strip]
    VALID_REGIONS = %w[header nav main aside footer dock]
    DEFAULT_BREAKPOINTS = { "sm" => 640, "md" => 768, "lg" => 1024, "xl" => 1280 }

    class << self
      def load(path)
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
        new(raw)
      end
    end

    attr_reader :slots, :navigation, :breakpoints, :home

    def initialize(raw)
      @slots = (raw["slots"] || []).map do |s|
        size = s["size"]
        region = s["region"]
        unless VALID_SIZES.include?(size)
          raise Dovetail::Error.new("D-CFG-001", "layout slot #{s["name"]} has an invalid size #{size.inspect}")
        end
        unless VALID_REGIONS.include?(region)
          raise Dovetail::Error.new("D-CFG-001", "layout slot #{s["name"]} has an invalid region #{region.inspect}")
        end
        {
          "name" => s["name"],
          "size" => size,
          "region" => region,
          "heading_level" => s["heading_level"]
        }
      end
      @navigation = (raw["navigation"] || []).map do |n|
        { "label_key" => n["label_key"], "module" => n["module"], "route" => n["route"] }
      end
      @breakpoints = raw["breakpoints"] || DEFAULT_BREAKPOINTS
      @home = raw["home"]
    end

    def slots_of_size(size)
      @slots.select { |s| s["size"] == size }
    end

    def slot_named(name)
      @slots.find { |s| s["name"] == name }
    end
  end
end
