require 'conversions'

class DataMiner
  class Attribute
    class << self
      def check_options(options)
        errors = []
        if (invalid_option_keys = options.keys - VALID_OPTIONS).any?
          errors << %{Invalid options: #{invalid_option_keys.map(&:inspect).to_sentence}}
        end
        if (units_options = options.select { |k, _| k.to_s.include?('units') }).any? and VALID_UNIT_DEFINITION_SETS.none? { |d| d.all? { |required_option| options[required_option].present? } }
          errors << %{#{units_options.inspect} is not a valid set of units definitions. Please supply a set like #{VALID_UNIT_DEFINITION_SETS.map(&:inspect).to_sentence}".}
        end
        errors
      end
    end

    VALID_OPTIONS = %w{
      from_units
      to_units
      static
      dictionary
      matcher
      field_name
      delimiter
      split
      units
      sprintf
      nullify
      overwrite
      upcase
      units_field_name
      units_field_number
      field_number
      chars
      synthesize
    }.map(&:to_sym)

    VALID_UNIT_DEFINITION_SETS = [
      [:units],
      [:from_units, :to_units],
      [:units_field_name],
      [:units_field_name, :to_units],
      [:units_field_number],
      [:units_field_number, :to_units],
    ]

    DEFAULT_SPLIT = /\s+/
    DEFAULT_KEEP = 0
    DEFAULT_DELIMITER = ', '
    DEFAULT_NULLIFY = false
    DEFAULT_UPCASE = false
    DEFAULT_OVERWRITE = true

    attr_reader :step
    attr_reader :name
    attr_reader :synthesize
    attr_reader :matcher
    attr_reader :dictionary
    attr_reader :field_number
    attr_reader :field_name
    # For use when joining a range of field numbers
    attr_reader :delimiter
    attr_reader :chars
    attr_reader :split
    attr_reader :to_units
    attr_reader :from_units
    attr_reader :units_field_number
    attr_reader :units_field_name
    attr_reader :sprintf
    attr_reader :static

    def initialize(step, name, options = {})
      options = options.symbolize_keys
      if (errors = Attribute.check_options(options)).any?
        raise ::ArgumentError, %{[data_miner] Errors on #{inspect}: #{errors.join(';')}}
      end
      @step = step
      @name = name
      @synthesize = options[:synthesize]
      if dictionary = options[:dictionary]
        @dictionary = dictionary.is_a?(Dictionary) ? dictionary : Dictionary.new(dictionary)
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
      @nullify_boolean = options.fetch :nullify, DEFAULT_NULLIFY
      @upcase_boolean = options.fetch :upcase, DEFAULT_UPCASE
      @from_units = options[:from_units]
      @to_units = options[:to_units] || options[:units]
      @sprintf = options[:sprintf]
      @overwrite_boolean = options.fetch :overwrite, DEFAULT_OVERWRITE
      @units_field_name = options[:units_field_name]
      @units_field_number = options[:units_field_number]
    end

    def model
      step.model
    end

    def static?
      @static_boolean
    end

    def nullify?
      @nullify_boolean
    end

    def upcase?
      @upcase_boolean
    end

    def convert?
      from_units.present? or units_field_name.present? or units_field_number.present?
    end

    def units?
      to_units.present? or units_field_name.present? or units_field_number.present?
    end

    def overwrite?
      @overwrite_boolean
    end
        
    def read(row)
      if matcher and matched_row = matcher.match(row)
        return matched_row
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
        pattern = split.fetch :pattern, DEFAULT_SPLIT
        keep = split.fetch :keep, DEFAULT_KEEP
        value = value.to_s.split(pattern)[keep].to_s
      end
      value = DataMiner.compress_whitespace value
      if nullify? and value.blank?
        return
      end
      if upcase?
        value = DataMiner.upcase value
      end
      if convert?
        final_from_units = from_units || read_units(row)
        final_to_units = to_units || read_units(row)
        if final_from_units.blank? or final_to_units.blank?
          raise ::RuntimeError, "[data_miner] Missing units (from=#{final_from_units.inspect}, to=#{final_to_units.inspect}"
        end
        value = value.to_f.convert final_from_units, final_to_units
      end
      if sprintf
        if sprintf.end_with?('f')
          value = value.to_f
        elsif sprintf.end_with?('d')
          value = value.to_i
        end
        value = sprintf % value
      end
      if dictionary
        value = dictionary.lookup(value)
      end
      value
    end

    def set_from_row(target, row)
      if overwrite? or target.send(name).nil?
        target.send "#{name}=", read(row)
      end
      if units? and ((final_to_units = (to_units || read_units(row))) or nullify?)
        target.send "#{name}_units=", final_to_units
      end
    end
        
    private

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
