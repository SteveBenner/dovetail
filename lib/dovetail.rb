require_relative "dovetail/version"
require_relative "dovetail/errors"
require_relative "dovetail/canonical_json"

module Dovetail
  autoload :Contract, "dovetail/contract"
  autoload :Negotiation, "dovetail/negotiation"
  autoload :Compiler, "dovetail/compiler"
  autoload :Shape, "dovetail/shape"
  autoload :Tokens, "dovetail/tokens"
  autoload :Signing, "dovetail/signing"
  autoload :Config, "dovetail/config"
  autoload :Layout, "dovetail/layout"
  autoload :Fuse, "dovetail/fuse"
  autoload :Verify, "dovetail/verify"
  autoload :Dev, "dovetail/dev"
  autoload :Messages, "dovetail/messages"
  autoload :CLI, "dovetail/cli"

  def self.root
    File.expand_path("..", __dir__)
  end
end
