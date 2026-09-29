module Dovetail
  module Contract
    Finding = Struct.new(:rule, :severity, :module_id, :message)
  end
end
