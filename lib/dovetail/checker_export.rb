require "fileutils"

module Dovetail
  module CheckerExport
    FILES = %w[
      exe/dovetail
      lib/dovetail.rb
      lib/dovetail/version.rb
      lib/dovetail/errors.rb
      lib/dovetail/canonical_json.rb
      lib/dovetail/cli.rb
      lib/dovetail/cli/check.rb
      lib/dovetail/cli/brief.rb
      lib/dovetail/cli/rules.rb
      lib/dovetail/config.rb
      lib/dovetail/shape.rb
      lib/dovetail/shape/report.rb
      lib/dovetail/shape/checker.rb
      lib/dovetail/shape/svelte_parser.rb
      lib/dovetail/shape/js_scanner.rb
      lib/dovetail/shape/css_parser.rb
      lib/dovetail/shape/finding.rb
      lib/dovetail/shape/rule_catalog.rb
      lib/dovetail/shape/rules.yml
      lib/dovetail/tokens.rb
      lib/dovetail/tokens/class_grammar.rb
      lib/dovetail/tokens/vocabulary.yml
      lib/dovetail/signing.rb
      lib/dovetail/compiler.rb
      lib/dovetail/compiler/title.rb
      lib/dovetail/compiler/json_schema.rb
      lib/dovetail/compiler/typescript.rb
      lib/dovetail/compiler/client.rb
      lib/dovetail/compiler/shape.rb
      lib/dovetail/compiler/registry.rb
      lib/dovetail/compiler/brief.rb
    ].freeze

    module_function

    def export(dir)
      target = File.expand_path(dir)
      if File.exist?(target)
        unless File.directory?(target)
          raise Dovetail::Error.new("D-USE-001", "#{target} exists and is not a directory")
        end
        unless Dir.children(target).empty?
          raise Dovetail::Error.new("D-USE-001", "#{target} already exists and is not empty")
        end
      end

      root = Dovetail.root
      FileUtils.mkdir_p(target)
      FILES.each do |relative|
        source = File.join(root, relative)
        unless File.file?(source)
          raise Dovetail::Error.new("D-USE-001", "missing source file #{relative}")
        end
        destination = File.join(target, relative)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination)
      end

      File.write(File.join(target, "VERSION"), "#{Dovetail::VERSION}\n")
      File.chmod(0o755, File.join(target, "exe", "dovetail"))
      target
    end
  end
end
