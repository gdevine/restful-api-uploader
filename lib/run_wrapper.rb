require File.expand_path(File.dirname(__FILE__) + '/wrapper_uploader')
require File.expand_path(File.dirname(__FILE__) + '/batch_uploader')
require File.expand_path(File.dirname(__FILE__) + '/batch_renamer')
require File.expand_path(File.dirname(__FILE__) + '/api_call_logger')

#wrapper_config = ARGV[0]
#transfer_config = ARGV[1]
#rename_config = ARGV[2]

wrapper_config = '/home/gerarddevine/dev/ror/restful-api-uploader/sample_wrapper_config.yml'
transfer_config = '/home/gerarddevine/dev/ror/restful-api-uploader/sample_transfer_config.yml'
renamer_config = '/home/gerarddevine/dev/ror/restful-api-uploader/sample_renamer_config.yml'


log_file_path = File.join(File.dirname(__FILE__), '..', 'log', 'log.txt')
log_writer = ApiCallLogger.new(log_file_path)

log_writer.log_message('INFO', 'windows_api_load starting...')

if (wrapper_config.nil? || wrapper_config.length == 0)
  log_writer.log_message('ERROR','You need to pass an argument containing the full path of the wrapper config yaml file')
  log_writer.log_message('INFO', 'Aborting...')
  # print error message here
  log_writer.close
  exit
end

if (transfer_config.nil? || transfer_config.length == 0)
  log_writer.log_message('ERROR','You need to pass an argument containing the full path of the transfer config yaml file')
  log_writer.log_message('INFO', 'Aborting...')
  # print error message here
  log_writer.close
  exit
end


if !File.exist?(wrapper_config)
  log_writer.log_message('ERROR',"Specified wrapper config file not found #{wrapper_config}")
  log_writer.log_message('INFO', 'Aborting...')
  # print error message here
  log_writer.close
  exit
end

if !File.exist?(transfer_config)
  log_writer.log_message('ERROR',"Specified transfer config file not found #{transfer_config}")
  log_writer.log_message('INFO', 'Aborting...')
  # print error message here
  log_writer.close
  exit
end

#run transfer first (to clean up old errors)
log_writer.log_message('INFO', "Step 1: Processing transfer config file...")
batch_uploader = BatchUploader.new(transfer_config, log_writer)
batch_uploader.run(1)

#then run wrapper for new uploads
log_writer.log_message('INFO', "Step 2: Processing wrapper config file...")
wrapper_uploader = WrapperUploader.new(wrapper_config, log_writer)
wrapper_uploader.run
log_writer.log_message('INFO', "Step 2: Upload wrapper has completed. Check results in #{File.absolute_path(wrapper_uploader.log_file_path)}") #WRITE SUMMARY HERE

#if a rename config file is provided, run it to rename files before HIEv upload
if File.exist?(renamer_config)
  log_writer.log_message('INFO', "Step 2b: Renaming upload files ")
  batch_renamer = BatchRenamer.new(renamer_config, log_writer)
  batch_renamer.run
  log_writer.log_message('INFO', "Step 2b: File renaming has completed. Check results in #{File.absolute_path(wrapper_uploader.log_file_path)}")
end

#run transfer again for new uploads
log_writer.log_message('INFO', "Step 3: Processing transfer config file")
batch_uploader = BatchUploader.new(transfer_config, log_writer)
batch_uploader.run(3)

log_writer.log_message('INFO', "Upload script has finished.")
log_writer.log_message('INFO', "------------------------------------------------")
log_writer.log_message('INFO', "")

log_writer.close