#!/usr/bin/env ruby
# encoding: utf-8
$LOAD_PATH << './'

begin
  found_gem = Gem::Specification.find_by_name('flickraw')
rescue Gem::LoadError
  puts "Could not find gem 'flickraw', try 'bundle install'"
  exit
end

require 'rubygems'
require 'flickraw'
require 'yaml'
require 'log'
require 'FileUtils'
require 'photosets'
require 'ruby-debug'

include Log

APP_CONFIG = YAML.load_file("config.yml")['defaults']

completed_path = ARGV[2]
upload_path = ARGV[1]
set_name = ARGV[0]

if set_name.nil? or set_name.empty? or
    upload_path.nil? or upload_path.empty? or !File.exists? upload_path or
    completed_path.nil? or completed_path.empty? or !File.exists? completed_path
  puts "invalid parameters or file path"
  puts "  usage:  ruby upload.rb <photoset_name> <upload_files_path> <completed_files_path>"
  exit
end

FlickRaw.api_key = APP_CONFIG['api_key']
FlickRaw.shared_secret = APP_CONFIG['shared_secret']
flickr.access_token = APP_CONFIG['access_token']
flickr.access_secret = APP_CONFIG['access_secret']
number_of_forks = APP_CONFIG['number_of_forks'] || 6




login = flickr.test.login
log "[MAIN] You are now authenticated as #{login.username}"


all_sets = Photosets.new(flickr.call("flickr.photosets.getList").each(&:to_hash))
all_files = Dir["#{upload_path}/**/*"] .select{|f|!File.directory?(f) and APP_CONFIG['allowed_ext'].include?(File.extname(f))}
log "[MAIN] about to process #{all_files.length} files from #{upload_path} using set #{set_name}"
#distribute based on file length so each batch is similar in size
file_batches = []
number_of_forks.times{file_batches << [[],0]}

all_files.each do |f|
  file_batch = file_batches.sort_by{|e| e.last}.first
  file_batch.first << f
  file_batch.push(file_batch.pop + File.size(f))
end


photo_set = nil
pids = []
file_batches.each_with_index do |batch,batch_index|
  pids << Process.fork do
    log "[WORKER-#{batch_index}] worker starting"
    batch.first.each do |file|
      tries = 0
      photo_id = nil
      file_ext = File.extname(file)
      file_time = File.mtime(file)
      while tries < (APP_CONFIG['retries'] || 3) and photo_id.nil?
        tries += 1
        begin
          photo_id = flickr.upload_photo file
          log("[WORKER-#{batch_index}] uploaded #{file} photo_id #{photo_id}")
          FileUtils.move(file, completed_path)
          log("[WORKER-#{batch_index}] moved #{file} to #{completed_path}")
        rescue Exception => e
          log("[WORKER-#{batch_index}] error uploading try ##{tries} #{file} due to: #{e.message}")
        end
      end
      if !photo_id.nil?
        begin
          # set video taken time here
          # find or create set
          photo_set ||= all_sets.get_set_by_title(set_name)
          if photo_set.nil?
            photo_set = flickr.photosets.create(:title => set_name, :primary_photo_id => photo_id)
            log("[WORKER-#{batch_index}] created set #{set_name} starting with photo #{photo_id}")
          else
            flickr.photosets.addPhoto(:photoset_id => photo_set.id, :photo_id => photo_id)
            log("[WORKER-#{batch_index}] photo #{photo_id} added to set #{set_name}")
          end
        rescue Exception => e
          log("[WORKER-#{batch_index}] error assigning set #{set_name} to #{file} due to: #{e.message}")
        end
      end
    end
    log("[WORKER-#{batch_index}] finished with uploading #{upload_path}")
  end
end
Process.waitall
log("[MAIN] finished with uploading #{upload_path}")

