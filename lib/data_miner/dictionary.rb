require 'remote_table'

class DataMiner
  class Dictionary
    DEFAULT_CASE_SENSITIVE = true

    attr_reader :key_name
    attr_reader :value_name
    attr_reader :sprintf
    attr_reader :url
    attr_reader :case_sensitive

    def initialize(options = {})
      options = options.symbolize_keys
      @mutex = ::Mutex.new
      @url = options[:url]
      @key_name = options[:input]
      @value_name = options[:output]
      @sprintf = options[:sprintf]
      @case_sensitive = options.fetch :case_sensitive, DEFAULT_CASE_SENSITIVE
    end
    
    def table
      @table || @mutex.synchronize do
        @table ||= ::RemoteTable.new(url).to_a # make sure it's fully cached
      end
    end
    
    def free
      @table = nil
    end
    
    def lookup(key)
      find key_name, key, value_name, {:sprintf => sprintf, :case_sensitive => case_sensitive}
    end
    
    def find(key_name, key, value_name, options = {})
      normalized_key = normalize_for_comparison(key, options)
      if match = table.detect { |row| normalized_key == normalize_for_comparison(row[key_name], options) }
        match[value_name].to_s
      end
    end
    
    private

    def normalize_for_comparison(str, options = {})
      if sprintf
        if sprintf.end_with?('f')
          str = str.to_f
        elsif sprintf.end_with?('d')
          str = str.to_i
        end
        str = sprintf % str
      end
      str = DataMiner.compress_whitespace str
      unless options[:case_sensitive]
        str = DataMiner.downcase str
      end
      str
    end
  end
end
