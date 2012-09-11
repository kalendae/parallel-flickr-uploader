module Log

  def log(str)
    @@f ||= File.open(YAML.load_file("config.yml")['defaults']['log_file'] || 'upload.log','a')
    puts "[#{Time.now.to_s}] #{str}"
    @@f.puts "[#{Time.now.to_s}] #{str}"
  end

end