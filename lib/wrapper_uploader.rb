require File.expand_path(File.dirname(__FILE__) + '/api_call_logger')
require 'rest-client'
require 'yaml'

class WrapperUploader

  attr_accessor :config
  attr_accessor :log_writer
  attr_accessor :log_file_path

  def initialize(config_path)
    self.config = YAML.load_file(config_path)
    self.log_file_path = File.join(File.dirname(__FILE__), '..', 'log', 'log.txt')
    self.log_writer = ApiCallLogger.new(log_file_path)
  rescue => e
    log_writer.log_general_error('Error while loading configuration', e)
    log_writer.close
    raise e
  end

  def run
    begin
      raise "Supplied YML file did not contain an array named 'files'" unless config['files'].is_a?(Array)
      config['files'].each { |file_config| prepare_and_stage_file(file_config) }
    ensure
      log_writer.close
    end
  end

  def get_files(path, file_pattern)
    files = []
    unless file_pattern.is_a?(Regexp)
      files << file_pattern
    else
      found_any = false
      Dir.foreach(path) do |file_name|
        if file_pattern =~ file_name
          files << file_name
          found_any = true
        end
      end
      raise "Did not find any files matching regular expression #{file_pattern}" unless found_any
    end
    files
  end

  def prepare_and_stage_file(file_config)
    begin
      src_path = file_config['path']
      src_file = file_config['file']
      backup_paths = file_config['destination']
      rotation = file_config['rotate']


    if file_pattern.is_a?(String)
      upload_file(source_path, file_pattern, post_params, transfer_to_path)
    elsif file_pattern.is_a?(Regexp)
     upload_file(source_path, file_pattern.to_s, post_params, transfer_to_path)
    else
      raise "Unrecognised file name, must be a String or Regexp, found #{file_pattern.class}"
    end

     if file_pattern.is_a?(String)
      upload_file(source_path, file_pattern, post_params, transfer_to_path)
    elsif file_pattern.is_a?(Regexp)
     upload_file(source_path, file_pattern.to_s, post_params, transfer_to_path)
    else
      raise "Unrecognised file name, must be a String or Regexp, found #{file_pattern.class}"
    end

      raise "Missing source path for file #{src_file} in wrapper_config.yml" if src_path.nil? or src_path.empty?
      raise "Missing file name in wrapper_config.yml. Must be a String or Regexp"  if src_file.nil? or !src_file.is_a?(String) and !src_file.is_a?(Regexp)
      raise "Missing destination path for file #{src_file} in wrapper_config.yml. Please specify at least one destination per file" if backup_paths.nil? or backup_paths.empty?
      dest_path = backup_paths.shift


      files = get_files(src_path, src_file)

      files.each do |file|
        source  = "#{src_path}/#{file}"
        #Construct new file name based on rotation params
        rotation_date = get_rotation_date(rotation)
        filename = get_dated_filename(file, rotation_date)

        temp_destination = File.join(dest_path, filename)
        if File.exist?(temp_destination)
          raise TempFileExistsException.new(temp_destination)
        end
        if !rotation_date.nil? && rotation_date.eql?(Date.today)
          FileUtils.mv source, temp_destination
        else
          FileUtils.cp source, temp_destination
        end

        backup_paths.each do |backup_path|
          backup_dest = File.join(backup_path, filename)
          unless temp_destination.eql?(backup_dest)
            FileUtils.cp temp_destination, backup_dest
          end
        end
      end
      #finished. invoker should now call transfer script.
    rescue TempFileExistsException => e
      log_writer.log_error(e)
    rescue RestClient::Exception => e
      log_writer.log_response(e.response)
    rescue
      log_writer.log_error($!)
    end
  end

  def get_rotation_date(rotation_type)
    unless rotation_type.nil?
      if rotation_type.eql?('daily')
        return Date.today
      elsif rotation_type.eql?('monthly')
        return  Date.civil(Date.today.year, Date.today.month, -1)
      elsif rotation_type.eql?('weekly')
        date  = Date.parse("Saturday")
        delta = date > Date.today ? 0 : 7
        return date + delta
      end
    end
  end

  def get_dated_filename(src_file, rotation_date)
    if rotation_date.nil?
      new_filename = src_file
    else
      date = rotation_date.strftime("%Y%m%d")
      new_filename = src_file.split('.').first
      new_filename << "_#{date}"
      if src_file.include?('.')
        new_filename << ".#{src_file.split('.').last}"
      end
    end
    new_filename
  end
end

class TempFileExistsException < RuntimeError
 def initialize(path)
    @path = path
  end

  def path
    @path
  end

  def ==(other)
    return false unless other.is_a?(TempFileExistsException)
    backup_path == other.backup_path
  end

  def message
    "File #{@path} already exists in upload queue. Upload of this file has been aborted."
  end
end

class ConfigurationException < RuntimeError
  def initialize(path)
    @path = path
  end

  def backup_path
    @path
  end

  def ==(other)
    return false unless other.is_a?(ConfigurationException)
    backup_path == other.backup_path
  end

  def message
    "yml configuration file #{@path} could not be interpreted. See user manual for a correct configuration example."
  end
end
