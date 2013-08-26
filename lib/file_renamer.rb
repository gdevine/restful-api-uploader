class FileRenamer

  attr_accessor :log_writer

  def initialize(log_writer)
    self.log_writer = log_writer
  end

  def rename_1(source_dir, orig_file)
    begin
      # --split the orig filename out
      elems = orig_file.split("_")
      new_file = 'FACE_' + 'AUTO_' + elems[1] + '_' + elems[3].upcase + '_R_' + elems[4]
      new_file_path = File.join(source_dir, new_file)
            
      orig_file_path = File.join(source_dir, orig_file)
      
      FileUtils.mv orig_file_path, new_file_path
    rescue
      log_writer.log_warning($!)
      false
    end
  end
  
  def rename_2(source_dir, orig_file)
    begin
      # --split the orig filename out
      elems = orig_file.split("_")
      new_file = 'FACE_' + 'AUTO_' + elems[1] + '_' + elems[3].upcase + '-' + elems[4].upcase + '_R_' + elems[5]
      new_file_path = File.join(source_dir, new_file)
            
      orig_file_path = File.join(source_dir, orig_file)
      
      FileUtils.mv orig_file_path, new_file_path
    rescue
      log_writer.log_warning($!)
      false   
    end   
  end

end