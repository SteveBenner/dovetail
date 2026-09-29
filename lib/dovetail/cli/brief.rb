require "json"

module Dovetail
  module CLI
    module Brief
      module_function

      def run(args, stdout:, stderr:)
        path = args.first
        if path.nil?
          stderr.puts("dovetail brief: a shape.json file is required")
          return 2
        end
        unless File.file?(path)
          raise Dovetail::Error.new("D-SHP-001", "shape file not found: #{path}")
        end
        brief_path = path.sub(/\.shape\.json\z/, ".brief.md")
        if brief_path != path && File.exist?(brief_path)
          stdout.puts(File.read(brief_path))
          return 0
        end
        raw = File.read(path)
        shape = begin
          JSON.parse(raw)
        rescue JSON::ParserError => e
          raise Dovetail::Error.new("D-SHP-001", "shape file is not valid JSON: #{e.message}")
        end
        unless shape.is_a?(Hash) && shape["schema"] == "dovetail.shape/v1"
          raise Dovetail::Error.new("D-SHP-001", "shape file has the wrong schema")
        end
        stdout.puts(Dovetail::Compiler::Brief.render_shape(shape))
        0
      end
    end
  end
end
