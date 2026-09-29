require_relative "lib/dovetail/version"

Gem::Specification.new do |spec|
  spec.name = "dovetail"
  spec.version = Dovetail::VERSION
  spec.summary = "A typed UI framework for fusing independently built frontend modules into one application."
  spec.authors = ["PaterasAI"]
  spec.license = "AGPL-3.0-only"
  spec.required_ruby_version = ">= 2.6.10"
  spec.files = Dir.glob(%w[lib/**/* exe/* templates/**/* runtime/src/**/* runtime/tools/**/* runtime/package.json runtime/package-lock.json specs/**/* README.md CHANGELOG.md VERSION], File::FNM_DOTMATCH).reject { |path| File.directory?(path) }
  spec.bindir = "exe"
  spec.executables = ["dovetail"]
  spec.require_paths = ["lib"]
end
