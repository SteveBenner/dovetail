require "json"
require "fileutils"
require_relative "bind"

module Dovetail
  class Fuse
    module Live
      module_function

      def resolve_files(globs, root)
        return [] if globs.nil? || globs.empty?
        globs.flat_map { |g| Dir.glob(File.join(root, g)) }
             .map { |p| File.expand_path(p) }
             .select { |p| File.file?(p) }
             .uniq
             .sort
      end

      def plan(files, root, live_base, module_dirs)
        expanded_root = File.expand_path(root)
        panel_dirs = module_dirs.map { |mod, dir| [File.expand_path(dir), mod] }.sort_by { |dir, _| -dir.length }
        files.each_with_index.map do |abs, index|
          rel = relative_path(abs, expanded_root)
          match = panel_dirs.find { |dir, _| abs == dir || abs.start_with?(dir + File::SEPARATOR) }
          unless match
            raise Dovetail::Error.new("D-FUS-001", "live component #{rel} is not inside any panel directory")
          end
          {
            "id" => "f#{index}",
            "abs" => abs,
            "rel" => rel,
            "specifier" => "#{live_base}#{rel}",
            "module" => match[1]
          }
        end
      end

      def relative_path(abs, root)
        prefix = "#{root}#{File::SEPARATOR}"
        rel = abs.start_with?(prefix) ? abs[prefix.length..-1] : abs
        rel.gsub(File::SEPARATOR, "/")
      end

      def stub_source(entry)
        <<~SVELTE
          <script>
            import { LiveHost } from '@dovetail/runtime/internal';
            let props = $props();
          </script>
          <LiveHost specifier=#{entry["specifier"].to_json} rel=#{entry["rel"].to_json} module=#{entry["module"].to_json} {...props} />
        SVELTE
      end

      def shim_source(entry)
        <<~TS
          import { loadLive } from '@dovetail/runtime/internal';
          const component = await loadLive(#{entry["specifier"].to_json}, #{entry["rel"].to_json}, #{entry["module"].to_json});
          export default component;
        TS
      end

      def write_entries(entries, out_dir)
        stub_dir = File.join(out_dir, "live-stubs")
        shim_dir = File.join(out_dir, "live-shims-src")
        FileUtils.mkdir_p(stub_dir)
        FileUtils.mkdir_p(shim_dir)
        entries.map do |entry|
          stub_path = File.join(stub_dir, "#{entry["id"]}.svelte")
          shim_path = File.join(shim_dir, "#{entry["id"]}.ts")
          File.write(stub_path, stub_source(entry))
          File.write(shim_path, shim_source(entry))
          entry.merge("stubPath" => stub_path, "shimSrcPath" => shim_path)
        end
      end

      def write_bind_sources(module_ids, out_dir)
        dir = File.join(out_dir, "live-bind-src")
        FileUtils.mkdir_p(dir)
        module_ids.each do |mod|
          File.write(File.join(dir, "#{mod}.ts"), Dovetail::Fuse::Bind.generate(mod))
        end
      end
    end
  end
end
