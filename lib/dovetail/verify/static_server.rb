require "socket"
require "thread"
require "json"

module Dovetail
  class Verify
    class StaticServer
      CONTENT_TYPES = {
        ".html" => "text/html; charset=utf-8",
        ".js" => "text/javascript; charset=utf-8",
        ".mjs" => "text/javascript; charset=utf-8",
        ".ts" => "text/plain; charset=utf-8",
        ".svelte" => "text/plain; charset=utf-8",
        ".css" => "text/css; charset=utf-8",
        ".json" => "application/json; charset=utf-8",
        ".svg" => "image/svg+xml",
        ".png" => "image/png",
        ".ico" => "image/x-icon",
        ".woff2" => "font/woff2"
      }

      LIVE_SOURCE_EXTENSIONS = %w[.svelte .ts .js].freeze

      def initialize(root)
        @root = File.expand_path(root)
        @live_base = nil
        @live_root = nil
        manifest_path = File.join(@root, ".dovetail-live.json")
        if File.file?(manifest_path)
          begin
            manifest = JSON.parse(File.read(manifest_path))
            @live_base = manifest["live_base"]
            @live_root = manifest["root"] ? File.expand_path(manifest["root"]) : nil
          rescue StandardError
            @live_base = nil
            @live_root = nil
          end
        end
        @server = TCPServer.new("127.0.0.1", 0)
        @running = true
        @thread = Thread.new { accept_loop }
      end

      def port
        @server.addr[1]
      end

      def stop
        @running = false
        @server.close rescue nil
        @thread.join(2) rescue nil
      end

      private

      def accept_loop
        while @running
          begin
            client = @server.accept
          rescue StandardError
            break
          end
          Thread.new(client) { |c| handle(c) }
        end
      end

      def percent_decode(path)
        path.gsub(/%([0-9A-Fa-f]{2})/) { [$1].pack("H2") }
      rescue StandardError
        path
      end

      def safe_path(decoded_path, base)
        candidate = File.expand_path(File.join(base, decoded_path))
        return nil unless candidate == base || candidate.start_with?(base + File::SEPARATOR)
        candidate
      end

      def live_relative_path(path)
        return nil unless @live_base && @live_root
        return nil unless path.start_with?(@live_base)
        path[@live_base.length..-1]
      end

      def handle(client)
        request_line = client.gets
        return unless request_line
        method, raw_path, = request_line.split(" ")
        while (line = client.gets) && line.strip != ""
        end
        if method.nil? || raw_path.nil?
          client.write("HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n")
          return
        end
        unless %w[GET HEAD].include?(method)
          client.write("HTTP/1.1 405 Method Not Allowed\r\nAllow: GET, HEAD\r\nConnection: close\r\n\r\n")
          return
        end
        raw_path = raw_path.split("?").first
        path = percent_decode(raw_path)
        path = "/index.html" if path == "/"
        if path == "/favicon.ico"
          client.write("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
          return
        end

        live_rel = live_relative_path(path)
        if live_rel
          file_path = safe_path(live_rel, @live_root)
          if file_path.nil? || !File.file?(file_path)
            client.write("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
          end
          body = File.binread(file_path)
          ext = File.extname(file_path)
          content_type = CONTENT_TYPES[ext] || "text/plain; charset=utf-8"
          client.write("HTTP/1.1 200 OK\r\nContent-Type: #{content_type}\r\nCache-Control: no-store\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
          client.write(body) if method == "GET"
          return
        end

        file_path = safe_path(path, @root)
        if file_path.nil?
          client.write("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
          return
        end
        if !File.file?(file_path) && File.extname(path).empty?
          file_path = File.join(@root, "index.html")
        end
        if File.file?(file_path)
          body = File.binread(file_path)
          ext = File.extname(file_path)
          content_type = CONTENT_TYPES[ext] || "application/octet-stream"
          extra_headers = LIVE_SOURCE_EXTENSIONS.include?(ext) ? "Cache-Control: no-store\r\n" : ""
          client.write("HTTP/1.1 200 OK\r\nContent-Type: #{content_type}\r\n#{extra_headers}Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
          client.write(body) if method == "GET"
        else
          client.write("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
        end
      rescue StandardError
      ensure
        client.close rescue nil
      end
    end
  end
end
