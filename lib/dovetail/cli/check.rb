require "optparse"
require "json"
require_relative "../shape"
require_relative "../signing"
require_relative "../canonical_json"

module Dovetail
  module CLI
    module Check
      module_function

      def run(args, stdout:, stderr:)
        options = { format: "text", require_signed: false, public_keys: [], profile: nil, changed: nil, shape_path: nil }
        parser = OptionParser.new do |o|
          o.on("--shape FILE") { |v| options[:shape_path] = v }
          o.on("--require-signed") { options[:require_signed] = true }
          o.on("--public-key FILE") { |v| options[:public_keys] << v }
          o.on("--format FORMAT") { |v| options[:format] = v }
          o.on("--profile PROFILE") { |v| options[:profile] = v }
          o.on("--changed FILE") { |v| options[:changed] = v }
        end
        remaining = parser.permute(args)

        json_positional = remaining.find { |a| a.end_with?(".json") }
        panel_positional = remaining.find { |a| a != json_positional }

        shape_path = options[:shape_path] || json_positional
        unless shape_path
          stderr.puts("dovetail: check requires --shape <file> or a positional shape.json")
          return 2
        end
        shape_path = File.expand_path(shape_path)
        panel_dir = File.expand_path(panel_positional || Dir.pwd)

        config = safe_config(panel_dir)

        unless File.file?(shape_path)
          raise Dovetail::Error.new("D-SHP-001", "shape file not found: #{shape_path}")
        end
        raw = File.read(shape_path)
        parsed = begin
          JSON.parse(raw)
        rescue JSON::ParserError => e
          raise Dovetail::Error.new("D-SHP-001", "shape file is not valid JSON: #{e.message}")
        end
        unless parsed.is_a?(Hash) && parsed["schema"] == "dovetail.shape/v1"
          raise Dovetail::Error.new("D-SHP-001", "shape file has the wrong schema")
        end

        profile = options[:profile] || parsed["rules_profile"] || (config && config.rules_profile) || "strict"

        if options[:require_signed]
          pems = collect_public_keys(options[:public_keys], config)
          if pems.empty?
            raise Dovetail::Error.new("D-SHP-003", "a signature is required but no public key is configured")
          end
          sig_path = Dovetail::Signing.signature_path(shape_path)
          unless File.file?(sig_path)
            raise Dovetail::Error.new("D-SHP-002", "no configured key verifies the shape signature")
          end
          sig_b64 = File.read(sig_path).strip
          result = Dovetail::Signing.verify(parsed, sig_b64, pems)
          unless result == :ok
            raise Dovetail::Error.new("D-SHP-002", "no configured key verifies the shape signature")
          end
        end

        report = Dovetail::Shape.check(panel_dir: panel_dir, shape: parsed, profile: profile, changed: options[:changed])

        if options[:format] == "json"
          stdout.puts(Dovetail::CanonicalJSON.pretty(report.to_h))
        else
          report.findings.each do |f|
            stdout.puts("#{f.file}:#{f.line}:#{f.column} #{f.rule} #{f.message} -> #{f.fix}")
          end
          stdout.puts("dovetail check: #{report.errors} errors, #{report.warnings} warnings") unless Dovetail::CLI.quiet
        end

        report.errors > 0 ? 1 : 0
      end

      def safe_config(panel_dir)
        Dovetail::Config.find(panel_dir)
      rescue StandardError
        nil
      end

      def collect_public_keys(flag_keys, config)
        paths = []
        paths.concat(flag_keys) unless flag_keys.empty?
        if paths.empty? && ENV["DOVETAIL_PUBLIC_KEYS"] && !ENV["DOVETAIL_PUBLIC_KEYS"].empty?
          paths.concat(ENV["DOVETAIL_PUBLIC_KEYS"].split(File::PATH_SEPARATOR))
        end
        if paths.empty? && config
          paths.concat(config.public_keys)
        end
        paths.reject { |p| p.nil? || p.empty? }.map do |p|
          path = File.expand_path(p)
          begin
            File.read(path)
          rescue SystemCallError
            raise Dovetail::Error.new("D-SHP-003", "public key file not readable: #{path}")
          end
        end
      end
    end
  end
end
