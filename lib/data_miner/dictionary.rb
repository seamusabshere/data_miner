require 'remote_table'
if RUBY_VERSION >= '1.9'
  begin
    require 'unicode_utils/downcase'
  rescue LoadError
    Kernel.warn '[data_miner] You may wish to include unicode_utils in your Gemfile to improve accuracy of downcasing'
  end
end

class DataMiner
  class Dictionary
    attr_reader :options
    def initialize(options = {})
      @options = options.symbolize_keys
    end
    
    def key_name
      options[:input]
    end
    
    def value_name
      options[:output]
    end
    
    def sprintf
      options[:sprintf] || '%s'
    end
    
    def case_sensitive
      true unless options[:case_sensitive] == false
    end
    
    def table
      @table ||= ::RemoteTable.new(options[:url]).to_a # convert to Array immediately
    end
    
    def free
      @table.free if @table.is_a?(::RemoteTable)
      @table = nil
    end
    
    def lookup(key)
      find key_name, key, value_name, {'sprintf' => sprintf, 'case_sensitive' => case_sensitive}
    end
    
    def find(key_name, key, value_name, options = {})
      normalized_key = normalize_for_comparison(key, options)
      if match = table.detect { |row| normalized_key == normalize_for_comparison(row[key_name], options) }
        match[value_name].to_s
      end
    end
    
    private
    
    def normalize_for_comparison(str, options = {})
      if options[:sprintf]
        if /\%[0-9\.]*f/.match options[:sprintf]
          str = str.to_f
        elsif /\%[0-9\.]*d/.match options[:sprintf]
          str = str.to_i
        end
        str = sprintf % str
      end
      str = str.to_s.strip
      unless options[:case_sensitive]
        str = defined?(::UnicodeUtils) ? ::UnicodeUtils.downcase(str) : str.downcase
      end
      str
    end
  end
end
