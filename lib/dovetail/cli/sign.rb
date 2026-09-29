require "optparse"
require "json"

module Dovetail
  module CLI
    module Sign
      module_function

      def run(args, stdout:, stderr:)
        private_key_path = nil
        parser = OptionParser.new do |o|
          o.on("--private-key PATH") { |v| private_key_path = v }
        end
        files = parser.parse(args)
        shape_path = files.first
        if shape_path.nil? || private_key_path.nil?
          stderr.puts("dovetail sign: a shape.json file and --private-key are required")
          return 2
        end
        shape = JSON.parse(File.read(shape_path))
        unless shape["schema"] == "dovetail.shape/v1"
          stderr.puts("D-SHP-001 the shape file is missing or not dovetail.shape/v1")
          return 2
        end
        private_key_pem = begin
          File.read(private_key_path)
        rescue StandardError => e
          stderr.puts("D-SHP-001 could not read the private key: #{e.message}")
          return 2
        end
        signature = Dovetail::Signing.sign(shape, private_key_pem)
        sig_path = Dovetail::Signing.signature_path(shape_path)
        File.write(sig_path, signature)
        stdout.puts(sig_path)
        0
      end
    end
  end
end
