module DataMiner
  class Attribute
    attr_accessor :klass, :name, :options_for_import

    def initialize(klass, name)
      @klass = klass
      @name = name
      @options_for_import = {}
    end
        
    def inspect
      "Attribute(#{klass}##{name})"
    end

    def stored_by?(import)
      options_for_import.has_key?(import)
    end
    
    def value_in_dictionary(import, key)
      return *dictionary(import).lookup(key) # strip the array wrapper if there's only one element
    end
    
    def value_in_source(import, row)
      if wants_static?(import)
        value = static(import)
      elsif field_number(import)
        if field_number(import).is_a?(Range)
          value = field_number(import).map { |n| row[n] }.join(delimiter(import))
        else
          value = row[field_number(import)]
        end
      else
        value = row[field_name(import)]
      end
      return nil if value.nil?
      return value if value.is_a?(ActiveRecord::Base) # escape valve for parsers that look up associations directly
      value = value.to_s
      value = value[chars(import)] if wants_chars?(import)
      value = do_split(import, value) if wants_split?(import)
      # taken from old errata... maybe we want to do this here
      value.gsub!(/[ ]+/, ' ')
      # text.gsub!('- ', '-')
      value.gsub!(/([^\\])~/, '\1 ')
      value.strip!
      value.upcase! if wants_upcase?(import)
      value = do_convert(import, row, value) if wants_conversion?(import)
      value = do_sprintf(import, value) if wants_sprintf?(import)
      value
    end
    
    def value_from_row(import, row)
      value = value_in_source(import, row)
      return value if value.is_a?(ActiveRecord::Base) # carry through trapdoor
      value = value_in_dictionary(import, value) if wants_dictionary?(import)
      value
    end
        
    # this will overwrite nils, even if wants_overwriting?(import) is false
    def set_record_from_row(import, record, row)
      return if !wants_overwriting?(import) and !record.send(name).nil?
      value = value_from_row(import, row)
      record.send "#{name}=", value
      DataMiner.logger.info("ActiveRecord didn't like trying to set #{klass}.#{name} = #{value}") if !value.nil? and record.send(name).nil?
    end

    def unit_from_source(import, row)
      row[units_field_name(import)].to_s.strip.underscore.to_sym
    end
    
    def do_convert(import, row, value)
      value.to_f.convert((from_units(import) || unit_from_source(import, row)), to_units(import))
    end
    
    def do_sprintf(import, value)
      if /\%[0-9\.]*f/.match(sprintf(import))
        value = value.to_f
      elsif /\%[0-9\.]*d/.match(sprintf(import))
        value = value.to_i
      end
      sprintf(import) % value
    end
    
    def do_split(import, value)
      pattern = split_options(import)[:pattern] || /\s+/ # default is split on whitespace
      keep = split_options(import)[:keep] || 0           # default is keep first element
      value.to_s.split(pattern)[keep].to_s
    end
  
    def column_type
      klass.columns_hash[name.to_s].type
    end
    
    def dictionary(import)
      raise "shouldn't ask for this" unless wants_dictionary?(import) # don't try to initialize if there are no dictionary options
      Dictionary.new dictionary_options(import)
    end
    
    # {
    #   :static => 'options_for_import[import].has_key?(:static)',
    #   :chars => :chars,
    #   :upcase => :upcase,
    #   :conversion => '!from_units(import).nil? or !units_field_name(import).nil?',
    #   :sprintf => :sprintf,
    #   :dictionary => :dictionary_options,
    #   :split => :split_options,
    #   :nullification => 'nullify(import) != false',
    #   :overwriting => 'overwrite(import) != false',
    # }.each do |name, condition|
    #   condition = "!#{condition}(import).nil?" if condition.is_a?(Symbol)
    #   puts <<-EOS
    #     def wants_#{name}?(import)
    #       #{condition}
    #     end
    #   EOS
    # end
    def wants_split?(import)
      !split_options(import).nil?
    end
    def wants_sprintf?(import)
      !sprintf(import).nil?
    end
    def wants_upcase?(import)
      !upcase(import).nil?
    end
    def wants_static?(import)
      options_for_import[import].has_key?(:static)
    end
    def wants_nullification?(import)
      nullify(import) != false
    end
    def wants_chars?(import)
      !chars(import).nil?
    end
    def wants_overwriting?(import)
      overwrite(import) != false
    end
    def wants_conversion?(import)
      !from_units(import).nil? or !units_field_name(import).nil?
    end
    def wants_dictionary?(import)
      !dictionary_options(import).nil?
    end
    
    # {
    #   :field_name => { :default => :name,                           :stringify => true },
    #   :delimiter      => { :default => '", "' }
    # }.each do |name, options|
    #   puts <<-EOS
    #     def #{name}(import)
    #       (options_for_import[import][:#{name}] || #{options[:default]})#{'.to_s' if options[:stringify]}
    #     end
    #   EOS
    # end
    def field_name(import)
      (options_for_import[import][:field_name] || name).to_s
    end
    def delimiter(import)
      (options_for_import[import][:delimiter] || ", ")
    end
    
    # %w(dictionary split).each do |name|
    #   puts <<-EOS
    #     def #{name}_options(import)
    #       options_for_import[import][:#{name}]
    #     end
    #   EOS
    # end
    def dictionary_options(import)
      options_for_import[import][:dictionary]
    end
    def split_options(import)
      options_for_import[import][:split]
    end
        
    # %w(from_units to_units conditions sprintf nullify overwrite upcase units_field_name field_number chars static).each do |name|
    #   puts <<-EOS
    #     def #{name}(import)
    #       options_for_import[import][:#{name}]
    #     end
    #   EOS
    # end
    def from_units(import)
      options_for_import[import][:from_units]
    end
    def to_units(import)
      options_for_import[import][:to_units]
    end
    def conditions(import)
      options_for_import[import][:conditions]
    end
    def sprintf(import)
      options_for_import[import][:sprintf]
    end
    def nullify(import)
      options_for_import[import][:nullify]
    end
    def overwrite(import)
      options_for_import[import][:overwrite]
    end
    def upcase(import)
      options_for_import[import][:upcase]
    end
    def units_field_name(import)
      options_for_import[import][:units_field_name]
    end
    def field_number(import)
      options_for_import[import][:field_number]
    end
    def chars(import)
      options_for_import[import][:chars]
    end
    def static(import)
      options_for_import[import][:static]
    end
  end
end
