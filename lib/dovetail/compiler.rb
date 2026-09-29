require "fileutils"
require_relative "compiler/title"
require_relative "compiler/json_schema"
require_relative "compiler/typescript"
require_relative "compiler/client"
require_relative "compiler/shape"
require_relative "compiler/registry"
require_relative "compiler/brief"

module Dovetail
  module Compiler
    module_function

    def compile(models, out:)
      findings = Contract.validate(models)
      if findings.any? { |f| f.severity == "error" }
        raise Dovetail::Error.new("D-CON-002", "contract validation failed", { findings: findings })
      end

      by_id = {}
      models.each { |m| by_id[m.module_id] = m }

      written = []
      models.each do |model|
        mod = model.module_id

        written << write_file(out, "schema/#{mod}.schema.json", Dovetail::CanonicalJSON.pretty(JsonSchema.generate(model)))
        written << write_file(out, "types/#{mod}.d.ts", Typescript.generate(model, by_id))
        written << write_file(out, "client/#{mod}.ts", Client.generate(model))

        if model.panel
          shape = Shape.generate(model)
          written << write_file(out, "shape/#{mod}.shape.json", Dovetail::CanonicalJSON.pretty(shape))
          written << write_file(out, "shape/#{mod}.brief.md", Brief.render(model, by_id))
          written << write_file(out, "registry/#{mod}.json", Dovetail::CanonicalJSON.pretty(Registry.generate(model)))
        end

        written << write_file(out, "model/#{mod}.model.json", Dovetail::CanonicalJSON.pretty(model.to_h))
      end
      written
    end

    def write_file(out, relative_path, content)
      full_path = File.join(out, relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.open(full_path, "wb") { |f| f.write(content) }
      relative_path
    end
  end
end
