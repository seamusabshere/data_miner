require 'remote_table'
class DataMiner
  class Dictionary
    attr_reader :options
    def initialize(options = {})
      @options = options.dup
      @options.stringify_keys!
    end
    
    def key_name
      options['input']
    end
    
    def value_name
      options['output']
    end
    
    def sprintf
      options['sprintf'] || '%s'
    end
    
    def case_sensitive
      true unless options['case_sensitive'] == false
    end
    
    def table
      @table ||= ::RemoteTable.new(options['url']).to_a # convert to Array immediately
    end
    
    def free
      @table.free if @table.is_a?(::RemoteTable)
      @table = nil
    end
    
    def lookup(key)
      find key_name, key, value_name, {'sprintf' => sprintf, 'case_sensitive' => case_sensitive}
    end
    
    def find(key_name, key, value_name, options = {})
      if match = table.detect { |row| normalize_for_comparison(key, options) == normalize_for_comparison(row[key_name], options) }
        match[value_name].to_s
      end
    end
    
    private
    
    def normalize_for_comparison(string, options = {})
      if options['sprintf']
        if /\%[0-9\.]*f/.match options['sprintf']
          string = string.to_f
        elsif /\%[0-9\.]*d/.match options['sprintf']
          string = string.to_i
        end
        string = sprintf % string
      end
      string.downcase! unless options['case_sensitive']
      string.to_s.strip
    end
  end
end
