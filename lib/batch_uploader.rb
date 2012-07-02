require File.expand_path(File.dirname(__FILE__) + '/api_call_logger')
require 'rest-client'
require 'yaml'

class BatchUploader

  attr_accessor :config
  attr_accessor :log_writer

  def initialize(config_path)
    self.config = YAML.load_file(config_path)
    log_file_path = File.join(File.dirname(__FILE__), '..', 'log', 'log.txt')
    self.log_writer = ApiCallLogger.new(log_file_path)
  end

  def run
    begin
      config['files'].each { |file_config| upload_file(file_config) }
    ensure
      log_writer.close
    end
  end

  def upload_file(file_config)
    begin
      url = config['api_endpoint']
      params = config['common_parameters']
      params.merge!(file_config['file_parameters'])

      file_path = file_config['path']
      file = File.new(file_path)

      params['file'] = file

      log_writer.log_request(params, url)
      response = RestClient.post url, params, accept: :json
      log_writer.log_response(response)
    rescue RestClient::Exception => e
      log_writer.log_response(e.response)
    rescue
      log_writer.log_error($!)
    end
  end
end