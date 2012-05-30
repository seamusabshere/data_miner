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
        units_options = options.select { |k, _| k.to_s.include?('units') }
        if units_options.any? and DataMiner.unit_converter.nil?
          errors << %{You must set DataMiner.unit_converter to :alchemist or :conversions if you wish to convert units}
        end
        if units_options.any? and VALID_UNIT_DEFINITION_SETS.none? { |d| d.all? { |required_option| options[required_option].present? } }
          errors << %{#{units_options.inspect} is not a valid set of units definitions. Please supply a set like #{VALID_UNIT_DEFINITION_SETS.map(&:inspect).to_sentence}".}
        end
        errors
      end
    end

    VALID_OPTIONS = [
      :from_units,
      :to_units,
      :static,
      :dictionary,
      :matcher,
      :field_name,
      :delimiter,
      :split,
      :units,
      :sprintf,
      :nullify, # deprecated
      :nullify_blank_strings,
      :overwrite,
      :upcase,
      :units_field_name,
      :units_field_number,
      :field_number,
      :chars,
      :synthesize,
    ]

    VALID_UNIT_DEFINITION_SETS = [
      [:units],                         # no conversion
      [:from_units, :to_units],         # yes
      [:units_field_name],              # no
      [:units_field_name, :to_units],   # yes
      [:units_field_number],            # no
      [:units_field_number, :to_units], # yes
    ]

    DEFAULT_SPLIT_PATTERN = /\s+/
    DEFAULT_SPLIT_KEEP = 0
    DEFAULT_DELIMITER = ', '
    DEFAULT_NULLIFY_BLANK_STRINGS = false
    DEFAULT_UPCASE = false
    DEFAULT_OVERWRITE = true

    # @private
    attr_reader :step
    
    # Local column name.
    # @return [Symbol]
    attr_reader :name
    
    # Synthesize a value by passing a proc that will receive +row+ and should return a final value.
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

    # Where to find the data in the row.
    # @return [Symbol]
    attr_reader :field_name

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

    # Final units. May invoke a conversion using https://rubygems.org/gems/alchemist
    #
    # If a local column named +[name]_units+ exists, it will be populated with this value.
    #
    # @return [Symbol]
    attr_reader :to_units

    # Initial units. May invoke a conversion using a conversion gem like https://rubygems.org/gems/alchemist
    # Be sure to set DataMiner.unit_converter
    # @return [Symbol]
    attr_reader :from_units

    # If every row specifies its own units, index of where to find the units. Zero-based.
    # @return [Integer]
    attr_reader :units_field_number

    # If every row specifies its own units, where to find the units.
    # @return [Symbol]
    attr_reader :units_field_name

    # A +sprintf+-style format to apply.
    # @return [String]
    attr_reader :sprintf

    # A static value to be used.
    # @return [String,Numeric,TrueClass,FalseClass,Object]
    attr_reader :static

    # Only meaningful for string columns. Whether to store blank input ("    ") as NULL. Defaults to DEFAULT_NULLIFY_BLANK_STRINGS.
    # @return [TrueClass,FalseClass]
    attr_reader :nullify_blank_strings

    # Whether to upcase value. Defaults to DEFAULT_UPCASE.
    # @return [TrueClass,FalseClass]
    attr_reader :upcase

    # Whether to overwrite the value in a local column if it is not null. Defaults to DEFAULT_OVERWRITE.
    # @return [TrueClass,FalseClass]
    attr_reader :overwrite

    # @private
    def initialize(step, name, options = {})
      options = options.symbolize_keys
      if (errors = Attribute.check_options(options)).any?
        raise ::ArgumentError, %{[data_miner] Errors on #{inspect}: #{errors.join(';')}}
      end
      @step = step
      @name = name.to_sym
      @synthesize = options[:synthesize]
      if @dictionary_boolean = options.has_key?(:dictionary)
        @dictionary_settings = options[:dictionary]
      end
      @matcher = options[:matcher].is_a?(::String) ? options[:matcher].constantize.new : options[:matcher]
      if @static_boolean = options.has_key?(:static)
        @static = options[:static]
      end
      @field_number = options[:field_number]
      @field_name = options.fetch(:field_name, name).to_sym
      @delimiter = options.fetch :delimiter, DEFAULT_DELIMITER
      @chars = options[:chars]
      if split = options[:split]
        @split = split.symbolize_keys
      end
      @nullify_blank_strings = if options.has_key?(:nullify)
        # deprecated
        options[:nullify]
      else
        options.fetch :nullify_blank_strings, DEFAULT_NULLIFY_BLANK_STRINGS
      end
      @upcase = options.fetch :upcase, DEFAULT_UPCASE
      @from_units = options[:from_units]
      @to_units = options[:to_units] || options[:units]
      @sprintf = options[:sprintf]
      @overwrite = options.fetch :overwrite, DEFAULT_OVERWRITE
      @units_field_name = options[:units_field_name]
      @units_field_number = options[:units_field_number]
      @convert_boolean = (@from_units.present? or (@to_units.present? and (@units_field_name.present? or @units_field_number.present?)))
      @persist_units_boolean = (@to_units.present? or @units_field_name.present? or @units_field_number.present?)
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
    def set_from_row(local_record, remote_row)
      previously_nil = local_record.send(name).nil?
      currently_nil = false

      if previously_nil or overwrite
        new_value = read remote_row
        local_record.send "#{name}=", new_value
        currently_nil = new_value.nil?
      end

      if not currently_nil and persist_units? and (final_to_units = (to_units || read_units(remote_row)))
        local_record.send "#{name}_units=", final_to_units
      end
    end

    # @private
    def read(row)
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
      if chars
        value = value[chars]
      end
      if split
        pattern = split.fetch :pattern, DEFAULT_SPLIT_PATTERN
        keep = split.fetch :keep, DEFAULT_SPLIT_KEEP
        value = value.to_s.split(pattern)[keep].to_s
      end
      if value.blank? and (not text_column? or nullify_blank_strings)
        return
      end
      value = DataMiner.compress_whitespace value
      if upcase
        value = DataMiner.upcase value
      end
      if convert?
        value = convert_units value, row
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
    def convert_units(value, row)
      final_from_units = from_units || read_units(row)
      final_to_units = to_units || read_units(row)
      unless final_from_units and final_to_units
        raise RuntimeError, "[data_miner] Missing units: from=#{final_from_units.inspect}, to=#{final_to_units.inspect}"
      end
      DataMiner.unit_converter.convert value, final_from_units, final_to_units
    end

    # @private
    def refresh
      @dictionary = nil
    end
        
    private

    def model
      step.model
    end

    def text_column?
      return @text_column_query[0] if @text_column_query.is_a?(Array)
      @text_column_query = [model.columns_hash[name.to_s].text?]
      @text_column_query[0]
    end

    def static?
      @static_boolean
    end

    def dictionary?
      @dictionary_boolean
    end

    def convert?
      @convert_boolean
    end

    def persist_units?
      @persist_units_boolean
    end

    def read_units(row)
      if units = row[units_field_name || units_field_number]
        DataMiner.compress_whitespace(units).underscore.to_sym
      end
    end

    def free
      @dictionary = nil
    end
  end
end
