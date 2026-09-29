module Dovetail
  module Negotiation
    module_function

    def compat(old_hash, new_hash)
      changes = Dovetail::Contract::Differ.diff(old_hash, new_hash)
      breaking = changes.select { |c| c.kind == :breaking }
      operations = {}
      (old_hash["operations"] || {}).each_key do |name|
        roots = [
          old_hash.dig("operations", name, "input"),
          old_hash.dig("operations", name, "output"),
          new_hash.dig("operations", name, "input"),
          new_hash.dig("operations", name, "output")
        ]
        operations[name] = verdict(breaking, "operation:#{name}", roots, old_hash, new_hash)
      end
      events = {}
      (old_hash["emits"] || {}).each_key do |name|
        roots = [
          old_hash.dig("emits", name, "payload"),
          new_hash.dig("emits", name, "payload")
        ]
        events[name] = verdict(breaking, "event:#{name}", roots, old_hash, new_hash)
      end
      {
        "schema" => "dovetail.compat/v1",
        "module" => new_hash["module"],
        "from" => old_hash["version"],
        "to" => new_hash["version"],
        "operations" => operations,
        "events" => events
      }
    end

    def verdict(breaking, subject, roots, old_hash, new_hash)
      subjects = [subject]
      reached = {}
      roots.each do |ref|
        reach(ref, old_hash["types"] || {}, reached)
        reach(ref, new_hash["types"] || {}, reached)
      end
      reached.each_key { |t| subjects << "type:#{t}" }
      affecting = breaking.select { |c| (c.subjects & subjects).any? }
      { "compatible" => affecting.empty?, "breaking" => affecting.map(&:description) }
    end

    def reach(ref, types, visited)
      return if ref.nil?
      case ref["kind"]
      when "named"
        name = ref["name"]
        return if visited.key?(name) && visited[name].include?(types.object_id)
        (visited[name] ||= []) << types.object_id
        type = types[name]
        return unless type
        (type["fields"] || []).each { |f| reach(f["type"], types, visited) }
      when "one_of"
        (ref["names"] || []).each { |n| reach({ "kind" => "named", "name" => n }, types, visited) }
      when "list", "map"
        reach(ref["of"], types, visited)
      when "inline"
        (ref["fields"] || []).each { |f| reach(f["type"], types, visited) }
      end
    end
  end
end
