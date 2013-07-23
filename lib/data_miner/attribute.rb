class DataMiner
  # A mapping between a local model column and a remote data source column.
  #
  # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
  # @see DataMiner::Step::Import#store Telling an import step to store a column with DataMiner::Step::Import#store
  # @see DataMiner::Step::Import#key Telling an import step to key on a column with DataMiner::Step::Import#key
  class Attribute
    class << self
      # @private
      def check_options(options)
        errors = []
        if options[:dictionary].is_a?(Dictionary)
          errors << %{:dictionary must be a Hash of options}
        end
        if (invalid_option_keys = options.keys - VALID_OPTIONS).any?
          errors << %{Invalid options: #{invalid_option_keys.map(&:inspect).to_sentence}}
        end
        errors
      end
    end

    VALID_OPTIONS = [
      :static,
      :dictionary,
      :matcher,
      :field_name,
      :delimiter,
      :split,
      :sprintf,
      :upcase,
      :field_number,
      :chars,
    ]

    DEFAULT_SPLIT_PATTERN = /\s+/
    DEFAULT_SPLIT_KEEP = 0
    DEFAULT_DELIMITER = ', '
    DEFAULT_UPCASE = false

    # activerecord-3.2.6/lib/active_record/connection_adapters/column.rb
    TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE', 'on', 'ON', 'yes', 'YES', 'y', 'Y']
    FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE', 'off', 'OFF', 'no', 'NO', 'n', 'N']

    # @private
    attr_reader :step
    
    # Local column name.
    # @return [Symbol]
    attr_reader :name
    
    # The block passed to a store argument. Synthesize a value by passing a proc that will receive +row+ and should return a final value.
    #
    # Unlike past versions of DataMiner, you pass this as a block, not with the :synthesize option.
    #
    # +row+ will be a +Hash+ with string keys or (less often) an +Array+
    #
    # @return [Proc]
    attr_reader :synthesize
    
    # An object that will be sent +#match(row)+ and should return a final value.
    #
    # Can be specified as a String which will be constantized into a class and an object of that class instantized with no arguments.
    #
    # +row+ will be a +Hash+ with string keys or (less often) an +Array+
    # @return [Object]
    attr_reader :matcher
    
    # Index of where to find the data in the row, starting from zero.
    #
    # If you pass a +Range+, then multiple fields will be joined together.
    #
    # @return [Integer, Range]
    attr_reader :field_number

    # A delimiter to be used when joining fields together into a single final value. Used when +:field_number+ is a +Range+. Defaults to DEFAULT_DELIMITER.
    # @return [String]
    attr_reader :delimiter

    # Which characters in a field to keep. Zero-based.
    # @return [Range]
    attr_reader :chars

    # How to split a field. You specify two options:
    #
    # +:pattern+: what to split on. Defaults to DEFAULT_SPLIT_PATTERN.
    # +:keep+: which of elements resulting from the split to keep. Defaults to DEFAULT_SPLIT_KEEP.
    #
    # @return [Hash]
    attr_reader :split

    # A +sprintf+-style format to apply.
    # @return [String]
    attr_reader :sprintf

    # A static value to be used.
    # @return [String,Numeric,TrueClass,FalseClass,Object]
    attr_reader :static

    # Whether to upcase value. Defaults to DEFAULT_UPCASE.
    # @return [TrueClass,FalseClass]
    attr_reader :upcase

    # @private
    def initialize(step, name, options = {}, &blk)
      options = options.symbolize_keys
      if (errors = Attribute.check_options(options)).any?
        raise ::ArgumentError, %{[data_miner] Errors on #{inspect}: #{errors.join(';')}}
      end
      @step = step
      @name = name.to_sym
      @synthesize = &blk if block_given?
      if @dictionary_boolean = options.has_key?(:dictionary)
        @dictionary_settings = options[:dictionary]
      end
      @matcher = options[:matcher].is_a?(::String) ? options[:matcher].constantize.new : options[:matcher]
      if @static_boolean = options.has_key?(:static)
        @static = options[:static]
      end
      @field_number = options[:field_number]
      @field_name = options[:field_name]
      @delimiter = options.fetch :delimiter, DEFAULT_DELIMITER
      @chars = options[:chars]
      if split = options[:split]
        @split = split.symbolize_keys
      end
      @upcase = options.fetch :upcase, DEFAULT_UPCASE
      @sprintf = options[:sprintf]
      @dictionary_mutex = ::Mutex.new
    end

    # Dictionary for translating.
    #
    # You pass a +Hash+ of options which is used to initialize a +DataMiner::Dictionary+.
    #
    # @return [DataMiner::Dictionary]
    def dictionary
      @dictionary || @dictionary_mutex.synchronize do
        @dictionary ||= Dictionary.new(@dictionary_settings)
      end
    end

    # @private
    def hstore_column
      return @hstore_column if defined?(@hstore_column)
      @hstore_column = name.to_s.split('.', 2)[0]
    end

    # @private
    def hstore_key
      return @hstore_key if defined?(@hstore_key)
      @hstore_key = name.to_s.split('.', 2)[1]
    end

    # Where to find the data in the row.
    # @return [Symbol]
    def field_name
      return @field_name if defined?(@field_name)
      @field_name = (hstore? ? hstore_key : name).to_sym
    end

    # # @private
    def set_from_row(local_record, remote_row)
      new_value = read remote_row
      if hstore?
        local_record.send(hstore_column)[hstore_key] = new_value
      else
        local_record.send("#{name}=", new_value)
      end
    end

    # @private
    def updates(remote_row)
      v = read remote_row
      if hstore?
        { hstore_column => { hstore_key => v } }
      else
        { name => v }
      end
    end

    # @private
    def read(row)
      if not column_exists?
        raise RuntimeError, "[data_miner] Table #{model.table_name} does not have column #{(hstore? ? hstore_column : name).inspect}"
      end
      if matcher and matcher_output = matcher.match(row)
        return matcher_output
      end
      if synthesize
        return synthesize.call(row)
      end
      value = if static?
        static
      elsif field_number
        if field_number.is_a?(::Range)
          field_number.map { |n| row[n] }.join(delimiter)
        else
          row[field_number]
        end
      elsif field_name == :row_hash
        row.row_hash
      elsif row.is_a?(::Hash) or row.is_a?(::ActiveSupport::OrderedHash)
        row[field_name.to_s] # remote_table hash keys are always strings
      end
      if value.nil?
        return
      end
      if value.is_a? ::ActiveRecord::Base
        return value
      end
      value = value.to_s
      if boolean_column?
        if TRUE_VALUES.include?(value)
          return true
        elsif FALSE_VALUES.include?(value)
          return false
        else
          return
        end
      end
      if number_column?
        period_position = value.rindex '.'
        comma_position = value.rindex ','
        # assume that ',' is a thousands separator and '.' is a decimal point unless we have evidence to the contrary
        if period_position and comma_position and comma_position > period_position
          # uncommon euro style 1.000,53
          value = value.delete('.').gsub(',', '.')
        elsif comma_position and comma_position > (value.length - 4)
          # uncommon euro style 1000,53
          value = value.gsub(',', '.')
        elsif comma_position
          # more common 1,000[.00] style - still don't want commas
          value = value.delete(',')
        end
      end
      if chars
        value = value[chars]
      end
      if split
        pattern = split.fetch :pattern, DEFAULT_SPLIT_PATTERN
        keep = split.fetch :keep, DEFAULT_SPLIT_KEEP
        value = value.to_s.split(pattern)[keep].to_s
      end
      if value.blank? # TODO false is "blank"
        return
      end
      value = DataMiner.compress_whitespace value
      if upcase
        value = DataMiner.upcase value
      end
      if sprintf
        if sprintf.end_with?('f')
          value = value.to_f
        elsif sprintf.end_with?('d')
          value = value.to_i
        end
        value = sprintf % value
      end
      if dictionary?
        value = dictionary.lookup(value)
      end
      value
    end

    # @private
    def refresh
      @dictionary = nil
    end

    def hstore?
      return @hstore_boolean if defined?(@hstore_boolean)
      @hstore_boolean = name.to_s.include?('.')
    end

    private

    def model
      step.model
    end

    def column_exists?
      return @column_exists_boolean if defined?(@column_exists_boolean)
      if hstore?
        @column_exists_boolean = model.column_names.include? hstore_column
      else
        @column_exists_boolean = model.column_names.include? name.to_s
      end
    end

    def text_column?
      return @text_column_boolean if defined?(@text_column_boolean)
      if hstore?
        @text_column_boolean = true
      else
        @text_column_boolean = model.columns_hash[name.to_s].text?
      end
    end
    
    def number_column?
      return @number_column_boolean if defined?(@number_column_boolean)
      if hstore?
        @number_column_boolean = false
      else
        @number_column_boolean = model.columns_hash[name.to_s].number?
      end
    end

    def boolean_column?
      return @boolean_column_boolean if defined?(@boolean_column_boolean)
      if hstore?
        @boolean_column_boolean = false
      else
        @boolean_column_boolean = (model.columns_hash[name.to_s].type == :boolean)
      end
    end

    def static?
      @static_boolean
    end

    def dictionary?
      @dictionary_boolean
    end

    def free
      @dictionary = nil
    end
  end
end
