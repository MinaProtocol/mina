# frozen_string_literal: true

module Citools
  module Utils
    # Utils extracting zips
    module Extract
      module_function

      def tar_gz(tar_path, target_dir)
        Zlib::GzipReader.open(tar_path) do |gz|
          Gem::Package::TarReader.new(gz) do |tar|
            tar.each do |entry|
              dest = File.join(target_dir, entry.full_name)
              if entry.directory?
                FileUtils.mkdir_p(dest)
              else
                FileUtils.mkdir_p(File.dirname(dest))
                File.write(dest, entry.read, mode: "wb")
              end
            end
          end
        end
      end
    end
  end
end
