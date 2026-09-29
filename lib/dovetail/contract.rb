require_relative "contract/naming"
require_relative "contract/validation"
require_relative "contract/scalar_marker"
require_relative "contract/composites"
require_relative "contract/type_ref"
require_relative "contract/builders"
require_relative "contract/eval_context"
require_relative "contract/ripper_check"
require_relative "contract/model"
require_relative "contract/finding"
require_relative "contract/change"
require_relative "contract/validator"
require_relative "contract/differ"

module Dovetail
  module Contract
    module_function

    def load_file(path)
      source = File.read(path)
      RipperCheck.check!(source, path)
      entry = DovetailEntry.new
      context = EvalContext.build(entry)
      begin
        context.instance_eval(source, path.to_s, 1)
      rescue Dovetail::Error
        raise
      rescue StandardError => e
        raise Dovetail::Error.new("D-CON-001", "#{path}: #{e.message}")
      end
      unless entry.declared?
        raise Dovetail::Error.new("D-CON-001", "#{path}: no contract was declared")
      end
      Model.new(entry.model_hash, entry.builder.duplicates)
    end

    def validate(models)
      Validator.validate(models)
    end

    def diff(old_model_hash, new_model_hash)
      Differ.diff(old_model_hash, new_model_hash)
    end

    def version_ok?(old_hash, new_hash, changes)
      Differ.version_ok?(old_hash, new_hash, changes)
    end
  end
end
