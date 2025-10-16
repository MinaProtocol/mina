# frozen_string_literal: true

require "net/http"
require "uri"

module Citools
  module Utils
    # Utils for downloading
    module Download
      module_function

      MAX_REDIRECTS = 5

      def http(url, dest_path, limit = MAX_REDIRECTS)
        raise "Too many redirects" if limit <= 0

        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Get.new(uri)

          http.request(request) do |response|
            case response
            when Net::HTTPSuccess
              File.open(dest_path, "wb") do |file|
                response.read_body { |chunk| file.write(chunk) }
              end
            when Net::HTTPRedirection
              location = response["location"]
              warn "Redirected to #{location}"
              return http(location, dest_path, limit - 1)
            else
              warn "Error downloading #{url}: #{response.code} #{response.message}"
              exit 1
            end
          end
        end
      end
    end
  end
end
