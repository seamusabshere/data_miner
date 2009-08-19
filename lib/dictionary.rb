module DataMiner
  class Dictionary
    attr_accessor :key_name, :value_name, :sprintf, :table

    def initialize(options = {})
      @key_name = options[:key]
      @value_name = options[:returns]
      @sprintf = options[:sprintf] || '%s'
      @table = RemoteTable.new(:url => options[:url])
    end

    def lookup(key)
      find(self.key_name, key, self.value_name, :sprintf => self.sprintf)
    end
    
    def find(key_name, key, value_name, options = {})
      if match = table.rows.detect { |row| normalize_for_comparison(key, options) == normalize_for_comparison(row[key_name], options) }
        match[value_name].to_s.split(/\s*;\s/)
      end
    end

    private

    def normalize_for_comparison(string, options = {})
      if options[:sprintf]
        if /\%[0-9\.]*f/.match(options[:sprintf])
          string = string.to_f
        elsif /\%[0-9\.]*d/.match(options[:sprintf])
          string = string.to_i
        end
        string = sprintf % string
      end
      string.to_s.strip
    end
  end
end
