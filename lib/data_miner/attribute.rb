require 'conversions'

class DataMiner
  class Attribute
    attr_reader :step
    attr_reader :name
    attr_reader :options

    def resource
      step.resource
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
    }

    def initialize(step, name, options = {})
      @options = ::DataMiner.recursively_stringify_keys options

      @step = step
      @name = name
      
      invalid_option_keys = @options.keys.select { |k| not VALID_OPTIONS.include? k }
      raise "Invalid options: #{invalid_option_keys.map(&:inspect).to_sentence} (#{inspect})" if invalid_option_keys.any?
    end
        
    def inspect
      %{#<DataMiner::Attribute(#{resource}##{name})>}
    end

    def value_in_dictionary(str)
      dictionary.lookup str
    end
    
    def value_in_source(row)
      value = if wants_static?
        static
      elsif field_number
        if field_number.is_a?(::Range)
          field_number.map { |n| row[n] }.join(delimiter)
        else
          row[field_number]
        end
      elsif field_name == 'row_hash'
        row.row_hash
      else
        row[field_name]
      end
      return nil if value.nil?
      return value if value.is_a?(::ActiveRecord::Base) # escape valve for parsers that look up associations directly
      value = value.to_s
      value = value[chars] if wants_chars?
      value = do_split(value) if wants_split?
      value.gsub! /[ ]+/, ' '
      value.strip!
      value.upcase! if wants_upcase?
      value = do_convert row, value if wants_conversion?
      value = do_sprintf value if wants_sprintf?
      value
    end
    
    def match_row(row)
      matcher.match row
    end
    
    def value_from_row(row)
      return match_row row if wants_matcher?
      value = value_in_source row
      return value if value.is_a? ::ActiveRecord::Base # carry through trapdoor
      value = value_in_dictionary value if wants_dictionary?
      value = synthesize.call(row) if wants_synthesize?
      value = nil if value.blank? and wants_nullification?
      value
    end
        
    def set_record_from_row(record, row)
      return false if !wants_overwriting? and !record.send(name).nil?
      record.send "#{name}=", value_from_row(row)
      record.send "#{name}_units=", (to_units || unit_from_source(row)).to_s if wants_units?
    end

    def unit_from_source(row)
      row[units_field_name || units_field_number].to_s.strip.underscore.to_sym
    end
    
    def do_convert(row, value)
      raise "If you use 'from_units', you need to set 'to_units' (#{inspect})" unless wants_units?
      value.to_f.convert((from_units || unit_from_source(row)), (to_units || unit_from_source(row)))
    end
    
    def do_sprintf(value)
      if /\%[0-9\.]*f/.match sprintf
        value = value.to_f
      elsif /\%[0-9\.]*d/.match sprintf
        value = value.to_i
      end
      sprintf % value
    end
    
    def do_split(value)
      pattern = split_options['pattern'] || /\s+/ # default is split on whitespace
      keep = split_options['keep'] || 0           # default is keep first element
      value.to_s.split(pattern)[keep].to_s
    end
  
    def column_type
      resource.columns_hash[name.to_s].type
    end
    
    # Our wants and needs :)
    def wants_split?
      split_options.present?
    end
    def wants_sprintf?
      sprintf.present?
    end
    def wants_upcase?
      upcase.present?
    end
    def wants_static?
      options.has_key? 'static'
    end
    def wants_nullification?
      nullify == true
    end
    def wants_chars?
      chars.present?
    end
    def wants_synthesize?
      synthesize.is_a?(::Proc)
    end
    def wants_overwriting?
      overwrite != false
    end
    def wants_conversion?
      from_units.present? or units_field_name.present? or units_field_number.present?
    end
    def wants_units?
      to_units.present? or units_field_name.present? or units_field_number.present?
    end
    def wants_dictionary?
      options['dictionary'].present?
    end
    def wants_matcher?
      options['matcher'].present?
    end

    # Options that always have values
    def field_name
      (options['field_name'] || name).to_s
    end
    def delimiter
      (options['delimiter'] || ', ')
    end
    
    # Options that can't be referred to by their names
    def split_options
      options['split']
    end
    
    def from_units
      options['from_units']
    end
    def to_units
      options['to_units'] || options['units']
    end
    def sprintf
      options['sprintf']
    end
    def nullify
      options['nullify']
    end
    def overwrite
      options['overwrite']
    end
    def upcase
      options['upcase']
    end
    def units_field_name
      options['units_field_name']
    end
    def units_field_number
      options['units_field_number']
    end
    def field_number
      options['field_number']
    end
    def chars
      options['chars']
    end
    def synthesize
      options['synthesize']
    end
    def static
      options['static']
    end
    # must be cleared before every run! (because it relies on remote data)
    def dictionary
      @dictionary ||= (options['dictionary'].is_a?(Dictionary) ? options['dictionary'] : Dictionary.new(options['dictionary']))
    end
    def matcher
      @matcher ||= (options['matcher'].is_a?(::String) ? options['matcher'].constantize.new : options['matcher'])
    end
    
    def free
      @dictionary.free if @dictionary.is_a?(Dictionary)
      @dictionary = nil
    end
  end
end
