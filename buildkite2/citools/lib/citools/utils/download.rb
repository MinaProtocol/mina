# frozen_string_literal: true

module Citools
  module Utils
    # Utils for downloading
    module Download
      def http(url, dest_path)
        uri = URI(url)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Get.new(uri)

          http.request(request) do |response|
            unless response.is_a?(Net::HTTPSuccess)
              warn "Error downloading #{url}: #{response.code} #{response.message}"
              exit 1
            end

            File.open(dest_path, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          end
        end
      end
    end
  end
end
