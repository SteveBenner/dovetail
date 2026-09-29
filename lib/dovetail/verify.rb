require "fileutils"
require_relative "verify/static_server"

module Dovetail
  class Verify
    def self.run(build_dir:, screenshots_dir:, timeout_s: 180)
      new(build_dir: build_dir, screenshots_dir: screenshots_dir, timeout_s: timeout_s).run
    end

    def initialize(build_dir:, screenshots_dir:, timeout_s: 180)
      @build_dir = File.expand_path(build_dir)
      @screenshots_dir = File.expand_path(screenshots_dir)
      @timeout_s = timeout_s
    end

    def run
      if RUBY_VERSION.split(".").first.to_i < 3
        raise Dovetail::Error.new("D-VER-002", "dovetail verify needs Ruby 3.0 or newer with the ferrum gem (bundle install --with verify)")
      end
      begin
        require "ferrum"
      rescue LoadError
        begin
          ENV["BUNDLE_GEMFILE"] = File.join(Dovetail.root, "Gemfile")
          require "bundler"
          Bundler.setup(:default, :verify)
          require "ferrum"
        rescue Exception
          raise Dovetail::Error.new("D-VER-002", "dovetail verify needs Ruby 3.0 or newer with the ferrum gem (bundle install --with verify)")
        end
      end
      require_relative "verify/journeys"

      FileUtils.mkdir_p(@screenshots_dir)
      server = StaticServer.new(@build_dir)
      browser_path = ENV["BROWSER_PATH"] || (File.exist?("/usr/bin/google-chrome") ? "/usr/bin/google-chrome" : nil)
      browser_options = { headless: true, timeout: @timeout_s }
      browser_options[:browser_path] = browser_path if browser_path
      browser = Ferrum::Browser.new(browser_options)
      begin
        page = browser.create_page
        exceptions = []
        exceptions_mutex = Mutex.new
        page.on("Runtime.exceptionThrown") do |params|
          details = params["exceptionDetails"] || {}
          text = details.dig("exception", "description") || details["text"] || details.to_s
          exceptions_mutex.synchronize { exceptions << text }
        end
        page.go_to("http://127.0.0.1:#{server.port}/")
        wait_for_ready(page)
        journeys = Journeys.new(page: page, screenshots_dir: @screenshots_dir, base_url: "http://127.0.0.1:#{server.port}", panel_entries: load_panel_entries, exceptions: exceptions)
        journeys.run_all
      ensure
        browser.quit rescue nil
        server.stop
      end
    end

    private

    def wait_for_ready(page, attempts: 100)
      attempts.times do
        ready = page.evaluate("window.__dovetail && window.__dovetail.ready()") rescue false
        return if ready
        sleep 0.1
      end
      raise Dovetail::Error.new("D-VER-002", "window.__dovetail never became ready")
    end

    def load_panel_entries
      generated_dir = File.join(File.dirname(@build_dir), "generated")
      registry_dir = File.join(generated_dir, "registry")
      return {} unless Dir.exist?(registry_dir)
      require "json"
      Dir.glob(File.join(registry_dir, "*.json")).each_with_object({}) do |path, h|
        entry = JSON.parse(File.read(path))
        h[entry["module"]] = entry
      end
    end
  end
end
