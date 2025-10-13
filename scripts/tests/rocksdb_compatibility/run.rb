#!/usr/bin/env ruby

# frozen_string_literal: true

require 'base64'
require 'net/http'
require 'openssl'
require 'rexml/document'
require 'rubygems/package'
require 'tmpdir'
require 'uri'
require 'zlib'
require 'rocksdb-ffi'

# WARN: this script rely on system RocksDB dynamic library

def download_file(url, dest_path)
  uri = URI(url)

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
    request = Net::HTTP::Get.new(uri)

    http.request(request) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        warn "Error downloading #{url}: #{response.code} #{response.message}"
        exit 1
      end

      File.open(dest_path, 'wb') do |file|
        response.read_body { |chunk| file.write(chunk) }
      end
    end
  end
end

def extract_tar_gz(tar_path, target_dir)
  Zlib::GzipReader.open(tar_path) do |gz|
    Gem::Package::TarReader.new(gz) do |tar|
      tar.each do |entry|
        dest = File.join(target_dir, entry.full_name)
        if entry.directory?
          FileUtils.mkdir_p(dest)
        else
          FileUtils.mkdir_p(File.dirname(dest))
          File.write(dest, entry.read, mode: 'wb')
        end
      end
    end
  end
end

# Public S3 bucket URL
url = 'https://snark-keys.o1test.net.s3.amazonaws.com/'
uri = URI(url)

# Match keys starting with "genesis_ledger" or "epoch_ledger" and ending with ".tar.gz"
pattern = /\A(genesis_ledger|epoch_ledger)_.*\.tar\.gz\z/

# Fetch all ledger tar files' name
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
# TODO: figure out how to enable SSL verification
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

request = Net::HTTP::Get.new(uri)
response = http.request(request)

tar_keys = []

unless response.is_a?(Net::HTTPSuccess)
  warn "Error: #{response.code} #{response.message}"
  exit 1
end

xml = REXML::Document.new(response.body)
xml.elements.each('ListBucketResult/Contents/Key') do |key_element|
  key = key_element.text
  tar_keys << key if key =~ pattern
end

if tar_keys.empty?
  warn 'No ledger tar files found.'
  exit 1
end

tar_keys.sample(5).each do |tar_key|
  tar_uri = "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net/#{tar_key}"

  puts "Testing RocksDB compatibility on #{tar_uri}"

  # Dir.mktmpdir do |dir|
  dir = Dir.mktmpdir
  tar_path = File.join(dir, File.basename(tar_key))

  puts "  Downloading to #{tar_path}..."
  download_file(tar_uri, tar_path)

  db_path = File.join(dir, 'extracted')
  puts "  Extracting to #{db_path}..."
  FileUtils.mkdir_p(db_path)
  extract_tar_gz(tar_path, db_path)

  puts "  Testing extracted RocksDB at #{db_path}"

  begin
    db = RocksDB.open(db_path)

    count = 0
    db.each do |key, value|
      puts "    Encounter a kv-pair #{Base64.strict_encode64(key)} => #{Base64.strict_encode64(value)}"
      count += 1
      break if count >= 5
    end

    db.close
  rescue StandardError => e
    warn "  Failed to open RocksDB at #{db_path}: #{e.class}: #{e.message}"
    exit 1
  end
end
