require File.expand_path(File.dirname(__FILE__) + '/api_call_logger')
require File.expand_path(File.dirname(__FILE__) + '/file_uploader')
require 'rest-client'
require 'yaml'

$count_files = 0
$count_success = 0
$total_file_size = 0
$warnings = 0

class BatchRenamer
  attr_accessor :config, :loc, :log_writer, :log_file_path

  def initialize(config_path, log_writer)
    self.log_file_path = File.join(File.dirname(__FILE__), '..', 'log', 'log.txt')
    self.log_writer = log_writer

    begin
      self.config = YAML.load_file(config_path)
      self.loc = config['source_directory']
      
      raise "Supplied YML file did not contain an array named 'files'" unless config['files'].is_a?(Array)
    rescue => e
      log_writer.log_error(e)
      #log_writer.close
      #raise e
    end

  end

  def run(step)
    # begin
      # config['files'].each do |group|
        # begin
          # routine = group['renamer_routine']
          # case routine
          # when "1"
            # puts '1!'
          # when "2"
            # puts 'Try harder!'
          # when "3"
            # puts '3!'
          # else
            # raise "renamer_routine not recognised"
          # end
        # rescue => e
          # $warnings += 1
          # log_writer.log_group_error(group, e)
        # end
      # end
    # ensure
      # $warnings = 0
    # end
    
    
    begin
      config['files'].each do |group|
        begin
          begin
          routine = group['renamer_routine']
          case routine
          when 1
            puts '1!'
          when 2
            puts 'Try harder!'
          when 3
            puts '3!'
          else
            raise "renamer_routine not recognised"
          end
        rescue => e
          $warnings += 1
          log_writer.log_group_error(group, e)
        end
        rescue => e
          $warnings += 1
          log_writer.log_group_error(group, e)
        end
      end
    ensure
      #log_writer.close
      human_file_size = '%.2f' % ($total_file_size.to_f / 2**20) #to megabytes
                                                                 #log the summary
      log_writer.log_message('INFO', "Step #{step} Completed: #{$warnings} warnings, #{$count_success}/#{$count_files} files transferred/attempted (#{human_file_size}MB)")
                                                                 #reset global variables
      $count_success = 0
      $count_files = 0
      $total_file_size = 0
      $warnings = 0
    end
    
    
    
  end


  def process_file_group(file_config)
    file_params = file_config['file_parameters']
    source_path = file_config['source_directory']
    file_pattern = file_config['file']
    transfer_to_path = file_config['transfer_to_directory']

    # make sure the source to path exists - this will raise an exception if it doesn't exist
    raise "Source path was not specified in transfer config yaml for file(s): #{file_pattern}" if source_path.nil? or source_path.empty?
    Dir.new(source_path)

    # make sure the transfer to path exists - this will raise an exception if it doesn't exist
    raise "Transfer_to path was not specified in transfer config yaml for file(s): #{file_pattern}" if transfer_to_path.nil? or transfer_to_path.empty?
    Dir.new(transfer_to_path)

    post_params = {}
    post_params.merge!(common_params)
    post_params.merge!(file_params)

    if file_pattern.is_a?(String)
      upload_file(source_path, file_pattern, post_params, transfer_to_path)
    elsif file_pattern.is_a?(Regexp)
      upload_file(source_path, file_pattern.to_s, post_params, transfer_to_path)
    else
      raise "Unrecognised file name, must be a String or Regexp, found #{file_pattern.class}"
    end
  end

  def upload_file(source_path, file_pattern, post_params, transfer_to_path)
    begin
      found_any = false
      Dir.foreach(source_path) do |file|
        if file.match(file_pattern)
          $count_files += 1
          file_path = File.join(source_path, file)
          timestamped_file = self.add_timestamp_to_file(file)
          dest_path = File.join(transfer_to_path, timestamped_file)
          success = file_uploader.upload(file_path, post_params)
          if success
            $count_success = $count_success + 1
            $total_file_size += File.size(file_path)
            FileUtils.mv file_path, dest_path
          end
          found_any = true
        end
      end
      raise "Did not find any files matching file #{file_pattern} in directory #{source_path}" unless (found_any)
    rescue
      $warnings += 1
      log_writer.log_warning($!)
    end



  end

  def add_timestamp_to_file(file_name)
    "#{DateTime.now.strftime("%Y%m%d%H%M%S")}-#{file_name}"
  end

end