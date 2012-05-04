require 'remote_table'

class DataMiner
  # An easy way to translate data before importing it using an intermediate table.
  class Dictionary
    DEFAULT_CASE_SENSITIVE = true

    # What field in the dictionary holds the lookup key.
    #
    # In other words, the column we scan down to find an entry.
    #
    # @return [String]
    attr_reader :key_name

    # What field in the dictionary holds the final value.
    #
    # @return [String]
    attr_reader :value_name

    # A +sprintf+-style format to be applied.
    # @return [String]
    attr_reader :sprintf

    # The URL of the dictionary. It must be a CSV.
    # @return [String]
    attr_reader :url

    # Whether to be case-sensitive with lookups. Defaults to false.
    # @return [TrueClass, FalseClass]
    attr_reader :case_sensitive

    # @private
    def initialize(options = {})
      options = options.symbolize_keys
      @url = options[:url]
      @key_name = options[:input].to_s
      @value_name = options[:output].to_s
      @sprintf = options[:sprintf]
      @case_sensitive = options.fetch :case_sensitive, DEFAULT_CASE_SENSITIVE
      @table_mutex = ::Mutex.new
    end
    
    # Look up a translation for a value.
    #
    # @return [nil, String]
    def lookup(value)
      normalized_value = normalize_for_comparison value
      if match = table.detect { |entry| entry[key_name] == normalized_value }
        match[value_name].to_s
      end
    end
    
    private

    def table
      @table || @table_mutex.synchronize do
        @table ||= ::RemoteTable.new(url).map do |entry|
          entry[key_name] = normalize_for_comparison entry[key_name]
          entry
        end
      end
    end
    
    def refresh
      @table = nil
    end

    def normalize_for_comparison(str)
      if sprintf
        if sprintf.end_with?('f')
          str = str.to_f
        elsif sprintf.end_with?('d')
          str = str.to_i
        end
        str = sprintf % str
      end
      str = DataMiner.compress_whitespace str
      unless case_sensitive
        str = DataMiner.downcase str
      end
      str
    end
  end
end
