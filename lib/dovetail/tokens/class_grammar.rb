module Dovetail
  module Tokens
    module ClassGrammar
      module_function

      SIZE_PREFIXES = %w[h w size min-h min-w max-h max-w].freeze
      SCREEN_UNITS = %w[dvh svh lvh dvw svw lvw].freeze
      SCREEN_EXACT = %w[h-screen w-screen size-screen min-h-screen max-h-screen min-w-screen max-w-screen].freeze

      def classify(class_name, path = nil)
        vocab = Tokens.vocabulary(path)
        return [:refused, "S-CSS-002", nil] if class_name.include?("[") || class_name.include?("]") || class_name.end_with?("!")

        segments = class_name.split(":")
        utility_part = segments.pop.to_s
        variants = segments

        variants.each do |variant|
          return [:refused, "S-CSS-002", nil] unless valid_variant?(variant, vocab)
        end

        negative = utility_part.start_with?("-")
        body = negative ? utility_part[1..-1] : utility_part

        return [:refused, "S-OVL-001", nil] if body == "fixed"
        return [:refused, "S-LAY-002", nil] if body =~ /\Az-/

        return [:refused, "S-LAY-001", nil] if screen_refused?(body)

        base, has_slash, opacity = body.rpartition("/")

        if has_slash != "" && color_utility?(base, vocab) && vocab.dig("utilities", "color", "opacity_modifiers").to_a.include?(opacity)
          return [:ok]
        end

        return [:ok] if grammar_match?(body, negative, vocab)

        [:refused, "S-CSS-001", suggest(class_name, vocab)]
      end

      def valid_variant?(variant, vocab)
        variants = vocab.fetch("variants")
        return true if Array(variants["pseudo"]).include?(variant)
        return true if Array(variants["breakpoints"]).include?(variant)
        return true if Array(variants["containers"]).include?(variant)
        if variant.start_with?("aria-")
          name = variant.sub("aria-", "")
          return true if Array(variants["aria"]).include?(name)
        end
        if variant.start_with?("data-")
          pattern = variants["data_pattern"]
          return true if pattern && variant =~ /\A#{pattern}\z/
        end
        false
      end

      def screen_refused?(body)
        return true if SCREEN_EXACT.include?(body)
        SIZE_PREFIXES.each do |prefix|
          next unless body.start_with?("#{prefix}-")
          value = body[(prefix.length + 1)..-1]
          return true if SCREEN_UNITS.include?(value)
        end
        false
      end

      def color_utility?(body, vocab)
        color = vocab.fetch("utilities").fetch("color")
        prefixes = Array(color["prefixes"]).sort_by { |p| -p.length }
        prefixes.each do |prefix|
          next unless body.start_with?("#{prefix}-")
          value = body[(prefix.length + 1)..-1]
          tokens = Array(vocab.dig("families", "color", "tokens"))
          keywords = Array(color["keywords"])
          return true if tokens.include?(value) || keywords.include?(value)
        end
        false
      end

      def grammar_match?(body, negative, vocab)
        utilities = vocab.fetch("utilities")

        unless negative
          return true if Array(utilities["static"]).include?(body)
          return true if numbered_match?(body, utilities["numbered"])
          return true if valued_match?(body, utilities["valued"])
          return true if radius_match?(body, utilities["radius"], vocab)
          return true if type_match?(body, utilities["type"], vocab)
          return true if weight_match?(body, utilities["type"], vocab)
          return true if shadow_match?(body, utilities["shadow"], vocab)
          return true if motion_match?(body, utilities["motion"], vocab)
          return true if color_utility?(body, vocab)
        end

        return true if space_match?(body, negative, utilities["space"], vocab)

        false
      end

      def numbered_match?(body, numbered)
        return false unless numbered
        numbered.each do |prefix, range|
          next unless body.start_with?("#{prefix}-")
          value = body[(prefix.length + 1)..-1]
          extra = Array(range["extra"])
          return true if extra.include?(value)
          if value =~ /\A\d+\z/
            n = value.to_i
            return true if n >= range["from"].to_i && n <= range["to"].to_i
          end
        end
        false
      end

      def valued_match?(body, valued)
        return false unless valued
        valued.each do |prefix, values|
          next unless body.start_with?("#{prefix}-")
          value = body[(prefix.length + 1)..-1]
          return true if Array(values).include?(value)
        end
        false
      end

      def radius_match?(body, radius, vocab)
        return false unless radius
        prefixes = Array(radius["prefixes"]).sort_by { |p| -p.length }
        tokens = Array(vocab.dig("families", "radius", "tokens"))
        prefixes.each do |prefix|
          next unless body.start_with?("#{prefix}-")
          value = body[(prefix.length + 1)..-1]
          return true if tokens.include?(value)
        end
        false
      end

      def type_match?(body, type, vocab)
        return false unless type
        prefix = type["size_prefix"]
        return false unless prefix && body.start_with?("#{prefix}-")
        value = body[(prefix.length + 1)..-1]
        Array(vocab.dig("families", "type", "tokens")).include?(value)
      end

      def weight_match?(body, weight, vocab)
        return false unless weight
        prefix = weight["weight_prefix"]
        return false unless prefix && body.start_with?("#{prefix}-")
        value = body[(prefix.length + 1)..-1]
        Array(vocab.dig("families", "weight", "tokens")).include?(value)
      end

      def shadow_match?(body, shadow, vocab)
        return false unless shadow
        prefix = shadow["prefix"]
        return false unless prefix && body.start_with?("#{prefix}-")
        value = body[(prefix.length + 1)..-1]
        Array(vocab.dig("families", "shadow", "tokens")).include?(value)
      end

      def motion_match?(body, motion, vocab)
        return false unless motion
        prefix = motion["prefix"]
        return false unless prefix && body.start_with?("#{prefix}-")
        value = body[(prefix.length + 1)..-1]
        Array(vocab.dig("families", "motion", "tokens")).include?(value)
      end

      def space_match?(body, negative, space, vocab)
        return false unless space
        prefixes = Array(space["prefixes"]).sort_by { |p| -p.length }
        tokens = Array(vocab.dig("families", "space", "tokens"))
        extra_values = Array(space["extra_values"])
        keywords = space["keywords"] || {}
        negatable = Array(space["negatable"])
        prefixes.each do |prefix|
          next unless body.start_with?("#{prefix}-")
          next if negative && !negatable.include?(prefix)
          value = body[(prefix.length + 1)..-1]
          return true if tokens.include?(value)
          return true if extra_values.include?(value)
          return true if Array(keywords[prefix]).include?(value)
        end
        false
      end

      def suggest(class_name, vocab)
        segments = class_name.split(":")
        utility_part = segments.pop.to_s
        prefix_variants = segments
        suggestions = vocab.fetch("suggestions")

        renamed = suggestions.dig("renames", utility_part)
        return join_variants(prefix_variants, renamed) if renamed

        negative = utility_part.start_with?("-")
        body = negative ? utility_part[1..-1] : utility_part

        neutral = suggest_neutral(body, vocab)
        return join_variants(prefix_variants, neutral) if neutral

        palette = suggest_palette(body, vocab)
        return join_variants(prefix_variants, palette) if palette

        keyword = suggest_keyword(body, vocab)
        return join_variants(prefix_variants, keyword) if keyword

        space = suggest_space(body, negative, vocab)
        return join_variants(prefix_variants, (negative ? "-#{space}" : space)) if space

        nil
      end

      def join_variants(variants, utility)
        return utility if variants.empty?
        "#{variants.join(':')}:#{utility}"
      end

      def suggest_neutral(body, vocab)
        neutral_hues = Array(vocab.dig("suggestions", "neutral_hues"))
        by_prefix = vocab.dig("suggestions", "neutral_by_prefix") || {}
        color = vocab.fetch("utilities").fetch("color")
        prefixes = Array(color["prefixes"]).sort_by { |p| -p.length }
        prefixes.each do |prefix|
          next unless body.start_with?("#{prefix}-")
          rest = body[(prefix.length + 1)..-1]
          match = rest.match(/\A(#{Regexp.union(neutral_hues)})-(\d+)\z/)
          next unless match
          shade = match[2].to_i
          bucket = by_prefix[prefix] || by_prefix["other"]
          next unless bucket
          bucket.each do |range, token|
            lo, hi = range.split("-").map(&:to_i)
            if shade >= lo && shade <= hi
              return "#{prefix}-#{token}"
            end
          end
        end
        nil
      end

      def suggest_palette(body, vocab)
        palette_hues = vocab.dig("suggestions", "palette_hues") || {}
        hue_to_semantic = {}
        palette_hues.each do |semantic, hues|
          Array(hues).each { |hue| hue_to_semantic[hue] = semantic }
        end
        color = vocab.fetch("utilities").fetch("color")
        prefixes = Array(color["prefixes"]).sort_by { |p| -p.length }
        prefixes.each do |prefix|
          next unless body.start_with?("#{prefix}-")
          rest = body[(prefix.length + 1)..-1]
          match = rest.match(/\A([a-z]+)-(\d+)\z/)
          next unless match
          semantic = hue_to_semantic[match[1]]
          next unless semantic
          return "#{prefix}-#{semantic}"
        end
        nil
      end

      def suggest_keyword(body, vocab)
        keywords = vocab.dig("suggestions", "keywords") || {}
        color = vocab.fetch("utilities").fetch("color")
        prefixes = Array(color["prefixes"]).sort_by { |p| -p.length }
        %w[white black].each do |keyword|
          prefixes.each do |prefix|
            next unless body == "#{prefix}-#{keyword}"
            mapping = keywords[keyword] || {}
            token = mapping[prefix] || mapping["other"]
            return "#{prefix}-#{token}" if token
          end
        end
        nil
      end

      def suggest_space(body, negative, vocab)
        space = vocab.fetch("utilities").fetch("space")
        prefixes = Array(space["prefixes"]).sort_by { |p| -p.length }
        negatable = Array(space["negatable"])
        numeric_tokens = Array(vocab.dig("families", "space", "tokens")).map(&:to_f)
        prefixes.each do |prefix|
          next unless body.start_with?("#{prefix}-")
          next if negative && !negatable.include?(prefix)
          value = body[(prefix.length + 1)..-1]
          next unless value =~ /\A\d+(\.\d+)?\z/
          n = value.to_f
          nearest = numeric_tokens.min_by { |t| [(t - n).abs, t] }
          next unless nearest
          formatted = nearest == nearest.to_i ? nearest.to_i.to_s : nearest.to_s
          return "#{prefix}-#{formatted}"
        end
        nil
      end
    end
  end
end
