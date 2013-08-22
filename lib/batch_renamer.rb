require File.expand_path(File.dirname(__FILE__) + '/api_call_logger')
require File.expand_path(File.dirname(__FILE__) + '/file_renamer')
require 'rest-client'
require 'yaml'

$count_files = 0
$count_success = 0
$total_file_size = 0
$warnings = 0

class BatchRenamer
  attr_accessor :config, :log_writer, :log_file_path, :file_renamer


  def initialize(config_path, log_writer)
    self.log_file_path = File.join(File.dirname(__FILE__), '..', 'log', 'log.txt')
    self.log_writer = log_writer
    
    begin
      self.config = YAML.load_file(config_path)
      self.file_renamer = FileRenamer.new(log_writer)
      
      raise "Supplied YML file did not contain an array named 'files'" unless config['files'].is_a?(Array)
    rescue => e
      log_writer.log_error(e)
      #log_writer.close
      #raise e
    end
  end
  
  
  def run(step)
    begin
      config['files'].each do |group|
        begin
          process_file_group(group)
        rescue => e
          $warnings += 1
          log_writer.log_group_error(group, e)
        end
      end
    ensure
      #log_writer.close
      human_file_size = '%.2f' % ($total_file_size.to_f / 2**20) #to megabytes
                                                                 #log the summary
      log_writer.log_message('INFO', "Step #{step} Completed: #{$warnings} warnings, #{$count_success}/#{$count_files} files renamed (#{human_file_size}MB)")
                                                                 #reset global variables
      $count_success = 0
      $count_files = 0
      $total_file_size = 0
      $warnings = 0
    end
  end
  
  
  def process_file_group(file_config)
    source_dir = file_config['source_directory']
    file_pattern = file_config['file']
    # --Pull out which renamer routine should be used  
    routine = file_config['renamer_routine']

    # make sure the source to path exists - this will raise an exception if it doesn't exist
    raise "Source path was not specified in transfer config yaml for file(s): #{file_pattern}" if source_dir.nil? or source_dir.empty?
    Dir.new(source_dir)

    if file_pattern.is_a?(String)
      rename_file(source_dir, file_pattern, routine)
    elsif file_pattern.is_a?(Regexp)
      rename_file(source_dir, file_pattern.to_s, routine)
    else
      raise "Unrecognised file name, must be a String or Regexp, found #{file_pattern.class}"
    end
  end


  def rename_file(source_dir, file_pattern, routine)
    begin
      found_any = false
      Dir.foreach(source_dir) do |file|
        if file.match(file_pattern)
          $count_files += 1
          file_path = File.join(source_dir, file)
          case routine
          when 1
            #pass in both the directory path and the filename
            success = file_renamer.rename_1(source_dir, file)
            puts '1!'
          when 2
            success = file_renamer.rename_2(file_path)
            puts '2!'
          else
            raise "renamer_routine not recognised"
          end
          
          if success
            $count_success = $count_success + 1
            $total_file_size += File.size(file_path)
            FileUtils.mv file_path, dest_path
          end
          found_any = true
        end
      end
      raise "Did not find any files matching file #{file_pattern} in directory #{source_dir}" unless (found_any)
    rescue
      $warnings += 1
      log_writer.log_warning($!)
    end
  end

end