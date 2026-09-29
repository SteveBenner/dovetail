module Dovetail
  class Fuse
    module Tailwind
      module_function

      def safelist_classes(vocabulary)
        families = vocabulary["families"]
        utilities = vocabulary["utilities"]
        classes = []

        Array(utilities["color"]["prefixes"]).each do |prefix|
          Array(families["color"]["tokens"]).each { |t| classes << "#{prefix}-#{t}" }
          Array(utilities["color"]["keywords"]).each { |k| classes << "#{prefix}-#{k}" }
        end

        negatable = Array(utilities["space"]["negatable"])
        space_keywords = utilities["space"]["keywords"] || {}
        Array(utilities["space"]["prefixes"]).each do |prefix|
          Array(families["space"]["tokens"]).each do |t|
            classes << "#{prefix}-#{t}"
            classes << "-#{prefix}-#{t}" if negatable.include?(prefix)
          end
          Array(utilities["space"]["extra_values"]).each { |v| classes << "#{prefix}-#{v}" }
          Array(space_keywords[prefix]).each { |k| classes << "#{prefix}-#{k}" }
        end

        Array(utilities["radius"]["prefixes"]).each do |prefix|
          Array(families["radius"]["tokens"]).each { |t| classes << "#{prefix}-#{t}" }
        end

        size_prefix = utilities["type"]["size_prefix"]
        Array(families["type"]["tokens"]).each { |t| classes << "#{size_prefix}-#{t}" }
        weight_prefix = utilities["type"]["weight_prefix"]
        Array(families["weight"]["tokens"]).each { |t| classes << "#{weight_prefix}-#{t}" }

        shadow_prefix = utilities["shadow"]["prefix"]
        Array(families["shadow"]["tokens"]).each { |t| classes << "#{shadow_prefix}-#{t}" }

        Array(utilities["static"]).each { |c| classes << c }

        (utilities["numbered"] || {}).each do |prefix, spec|
          (spec["from"]..spec["to"]).each { |n| classes << "#{prefix}-#{n}" }
          Array(spec["extra"]).each { |e| classes << "#{prefix}-#{e}" }
        end

        (utilities["valued"] || {}).each do |prefix, values|
          Array(values).each { |v| classes << "#{prefix}-#{v}" }
        end

        classes.uniq!

        pseudo = Array(vocabulary["variants"]["pseudo"])
        with_variants = classes.dup
        pseudo.each do |variant|
          classes.each { |c| with_variants << "#{variant}:#{c}" }
        end

        with_variants.uniq
      end

      def safelist_source(vocabulary)
        classes = safelist_classes(vocabulary)
        "@source inline(\"#{classes.join(" ")}\");"
      end

      def entry_css(vocabulary, panel_dirs, shell_dir, live: false)
        color_tokens = vocabulary["families"]["color"]["tokens"]
        radius_tokens = vocabulary["families"]["radius"]["tokens"]
        type_tokens = vocabulary["families"]["type"]["tokens"]
        weight_tokens = vocabulary["families"]["weight"]["tokens"]
        shadow_tokens = vocabulary["families"]["shadow"]["tokens"]

        lines = []
        lines << '@import "tailwindcss";'
        panel_dirs.each { |d| lines << "@source \"#{d}\";" }
        lines << "@source \"#{shell_dir}\";"
        lines << safelist_source(vocabulary) if live
        lines << '@custom-variant dark (&:where([data-color-scheme=dark], [data-color-scheme=dark] *));'
        lines << "@theme inline {"
        lines << "  --*: initial;"
        color_tokens.each { |t| lines << "  --color-#{t}: var(--#{t});" }
        lines << "  --color-transparent: transparent;"
        lines << "  --color-current: currentColor;"
        lines << "  --spacing: var(--space-1);"
        radius_tokens.each { |t| lines << "  --radius-#{t}: var(--corner-#{t});" }
        type_tokens.each { |t| lines << "  --text-#{t}: var(--type-#{t});" }
        type_tokens.each { |t| lines << "  --text-#{t}--line-height: var(--type-#{t}-leading);" }
        weight_tokens.each { |t| lines << "  --font-weight-#{t}: var(--weight-#{t});" }
        shadow_tokens.each { |t| lines << "  --shadow-#{t}: var(--elevation-#{t});" }
        lines << "  --font-sans: var(--family-sans);"
        lines << "  --font-mono: var(--family-mono);"
        lines << "  --ease-theme: var(--motion-ease);"
        lines << "  --default-transition-duration: var(--motion-base);"
        lines << "  --default-transition-timing-function: var(--motion-ease);"
        lines << "  --breakpoint-sm: 640px; --breakpoint-md: 768px; --breakpoint-lg: 1024px; --breakpoint-xl: 1280px;"
        lines << "  --container-sm: 320px; --container-md: 480px; --container-lg: 640px; --container-xl: 800px;"
        lines << "  --leading-none: 1; --leading-tight: 1.25; --leading-snug: 1.375; --leading-normal: 1.5; --leading-relaxed: 1.625;"
        lines << "  --tracking-tight: -0.025em; --tracking-normal: 0em; --tracking-wide: 0.025em;"
        lines << "  --animate-pulse: pulse 1.6s ease-in-out infinite;"
        lines << "  --animate-spin: spin 1s linear infinite;"
        lines << "}"
        lines << "@utility duration-fast { transition-duration: var(--motion-fast); }"
        lines << "@utility duration-base { transition-duration: var(--motion-base); }"
        lines << "@utility duration-slow { transition-duration: var(--motion-slow); }"
        lines << "@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.55; } }"
        lines << "@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }"
        lines.join("\n") + "\n"
      end
    end
  end
end
