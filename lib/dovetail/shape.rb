require_relative "shape/report"
require_relative "shape/checker"

module Dovetail
  module Shape
    module_function

    def check(panel_dir:, shape:, profile: "strict", changed: nil)
      Checker.new(panel_dir: panel_dir, shape: shape, profile: profile, changed: changed).run
    end
  end
end
