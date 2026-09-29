require "fileutils"
require "yaml"
require "dovetail/config"

module Dovetail
  module CLI
    module New
      class << self
        def run(args, stdout:, stderr:)
          kind = args.shift
          name = args.shift
          if name.nil? || !%w[shell panel].include?(kind)
            raise Dovetail::Error.new("D-USE-001", "usage is dovetail new shell|panel <name>")
          end
          case kind
          when "shell"
            new_shell(name, stdout: stdout, stderr: stderr)
          when "panel"
            new_panel(name, stdout: stdout, stderr: stderr)
          end
        end

        private

        def templates_dir
          File.join(Dovetail.root, "templates")
        end

        def new_shell(name, stdout:, stderr:)
          target = File.expand_path(name)
          if File.exist?(target)
            stderr.puts("dovetail new: #{target} already exists")
            return 1
          end
          FileUtils.mkdir_p(target)
          copy_tree(File.join(templates_dir, "shell"), target, {})
          FileUtils.mkdir_p(File.join(target, "modules"))
          stdout.puts("created #{target}") unless Dovetail::CLI.quiet
          0
        end

        def new_panel(name, stdout:, stderr:)
          config = Dovetail::Config.find(Dir.pwd)
          unless config
            raise Dovetail::Error.new("D-CFG-001", "no dovetail.yml found above #{Dir.pwd}")
          end
          module_dir = File.join(config.root, "modules", name)
          if File.exist?(module_dir)
            stderr.puts("dovetail new: #{module_dir} already exists")
            return 1
          end
          namespace = "/" + name.to_s.gsub("_", "-")
          title = name.to_s.split("_").map { |w| w[0].upcase + w[1..-1].to_s }.join(" ")
          substitutions = { "{{module}}" => name, "{{Module}}" => title, "{{namespace}}" => namespace }

          FileUtils.mkdir_p(module_dir)
          copy_file(File.join(templates_dir, "panel", "contract.rb"), File.join(module_dir, "contract.rb"), substitutions)
          copy_tree(File.join(templates_dir, "panel", "src"), File.join(module_dir, "panel", "src"), substitutions)
          copy_tree(File.join(templates_dir, "panel", "messages"), File.join(module_dir, "panel", "messages"), substitutions)
          FileUtils.cp(File.join(templates_dir, "panel", "README.md"), File.join(module_dir, "panel", "README.md")) if File.file?(File.join(templates_dir, "panel", "README.md"))
          substitute_in_place(File.join(module_dir, "panel", "README.md"), substitutions) if File.file?(File.join(module_dir, "panel", "README.md"))

          update_layout(config, name, namespace)
          stdout.puts("created #{module_dir}") unless Dovetail::CLI.quiet
          0
        end

        def copy_tree(src, dest, substitutions)
          return unless Dir.exist?(src)
          FileUtils.mkdir_p(dest)
          Dir.children(src).sort.each do |entry|
            src_path = File.join(src, entry)
            dest_path = File.join(dest, entry)
            if File.directory?(src_path)
              copy_tree(src_path, dest_path, substitutions)
            else
              copy_file(src_path, dest_path, substitutions)
            end
          end
        end

        def copy_file(src_path, dest_path, substitutions)
          FileUtils.mkdir_p(File.dirname(dest_path))
          content = File.binread(src_path)
          if text_file?(src_path)
            substitutions.each { |k, v| content = content.gsub(k, v.to_s) }
          end
          File.binwrite(dest_path, content)
        end

        def substitute_in_place(path, substitutions)
          content = File.read(path)
          substitutions.each { |k, v| content = content.gsub(k, v.to_s) }
          File.write(path, content)
        end

        def text_file?(path)
          !path.end_with?(".keep")
        end

        def update_layout(config, module_name, namespace)
          layout_path = config.layout
          return unless File.file?(layout_path)
          text = File.read(layout_path)
          raw = YAML.safe_load(text, permitted_classes: [], aliases: false) || {}
          nav = raw["navigation"] || []
          already_present = nav.any? { |n| n["module"] == module_name.to_s }
          home_is_null = !raw.key?("home") || raw["home"].nil?

          if home_is_null
            replaced = text.sub(/^home:[ \t]*(null|~|)[ \t]*$/, "home: #{module_name}")
            text = replaced if replaced != text
          end

          unless already_present
            entry = "  - label_key: \"#{module_name}.title\"\n    module: #{module_name}\n    route: #{namespace}\n"
            if text =~ /^navigation:[ \t]*\[\][ \t]*$/
              text = text.sub(/^navigation:[ \t]*\[\][ \t]*$/, "navigation:\n" + entry.chomp)
            elsif text =~ /^navigation:[ \t]*$/
              lines = text.lines
              idx = lines.index { |l| l =~ /^navigation:[ \t]*$/ }
              insert_at = idx + 1
              insert_at += 1 while insert_at < lines.length && lines[insert_at] =~ /^[ \t]+\S/
              lines.insert(insert_at, entry)
              text = lines.join
            else
              text = text.rstrip + "\nnavigation:\n" + entry
            end
          end

          File.write(layout_path, text)
        end
      end
    end
  end
end
