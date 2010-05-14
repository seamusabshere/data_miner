module DataMiner
  class Attribute
    attr_accessor :step
    attr_accessor :name
    attr_accessor :options

    delegate :resource, :to => :step

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
      :nullify,
      :overwrite,
      :upcase,
      :units_field_name,
      :units_field_number,
      :field_number,
      :chars,
      :synthesize
    ]

    def initialize(step, name, options = {})
      options.symbolize_keys!

      @step = step
      @name = name
      
      invalid_option_keys = options.keys.select { |k| not VALID_OPTIONS.include? k }
      DataMiner.log_or_raise "Invalid options: #{invalid_option_keys.map(&:inspect).to_sentence} (#{inspect})" if invalid_option_keys.any?
      @options = options
    end
        
    def inspect
      "Attribute(#{resource}##{name})"
    end

    def value_in_dictionary(str)
      dictionary.lookup str
    end
    
    def value_in_source(row)
      if wants_static?
        value = static
      elsif field_number
        if field_number.is_a?(Range)
          value = field_number.map { |n| row[n] }.join(delimiter)
        else
          value = row[field_number]
        end
      else
        value = row[field_name]
      end
      return nil if value.nil?
      return value if value.is_a?(ActiveRecord::Base) # escape valve for parsers that look up associations directly
      value = value.to_s
      value = value[chars] if wants_chars?
      value = do_split(value) if wants_split?
      # taken from old errata... maybe we want to do this here
      value.gsub! /[ ]+/, ' '
      # text.gsub!('- ', '-')
      value.gsub! /([^\\])~/, '\1 '
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
      return value if value.is_a? ActiveRecord::Base # carry through trapdoor
      value = value_in_dictionary value if wants_dictionary?
      value = synthesize.call(row) if wants_synthesize?
      value
    end
        
    # this will overwrite nils, even if wants_overwriting? is false
    # returns true if an attr was changed, otherwise false
    def set_record_from_row(record, row)
      return false if !wants_overwriting? and !record.send(name).nil?
      what_it_was = record.send name
      what_it_should_be = value_from_row row

      record.send "#{name}=", what_it_should_be
      record.send "#{name}_units=", (to_units || unit_from_source(row)).to_s if wants_units?
      
      what_it_is = record.send name
      if what_it_is.nil? and !what_it_should_be.nil?
        DataMiner.log_info "ActiveRecord didn't like trying to set #{resource}.#{name} = #{what_it_should_be} (it came out as nil)"
        nil
      elsif what_it_is == what_it_was
        false
      else
        true
      end
    end

    def unit_from_source(row)
      row[units_field_name || units_field_number].to_s.strip.underscore.to_sym
    end
    
    def do_convert(row, value)
      DataMiner.log_or_raise "If you use :from_units, you need to set :to_units (#{inspect})" unless wants_units?
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
      pattern = split_options[:pattern] || /\s+/ # default is split on whitespace
      keep = split_options[:keep] || 0           # default is keep first element
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
      options.has_key? :static
    end
    def wants_nullification?
      nullify != false
    end
    def wants_chars?
      chars.present?
    end
    def wants_synthesize?
      synthesize.is_a?(Proc)
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
      options[:dictionary].present?
    end
    def wants_matcher?
      options[:matcher].present?
    end

    # Options that always have values
    def field_name
      (options[:field_name] || name).to_s
    end
    def delimiter
      (options[:delimiter] || ', ')
    end
    
    # Options that can't be referred to by their names
    def split_options
      options[:split]
    end
    
    def from_units
      options[:from_units]
    end
    def to_units
      options[:to_units] || options[:units]
    end
    def sprintf
      options[:sprintf]
    end
    def nullify
      options[:nullify]
    end
    def overwrite
      options[:overwrite]
    end
    def upcase
      options[:upcase]
    end
    def units_field_name
      options[:units_field_name]
    end
    def units_field_number
      options[:units_field_number]
    end
    def field_number
      options[:field_number]
    end
    def chars
      options[:chars]
    end
    def synthesize
      options[:synthesize]
    end
    def static
      options[:static]
    end
    def dictionary
      @_dictionary ||= Dictionary.new options[:dictionary]
    end
    def matcher
      @_matcher ||= (options[:matcher].is_a?(String) ? options[:matcher].constantize.new : options[:matcher])
    end
  end
end
