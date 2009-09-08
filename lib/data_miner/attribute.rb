module DataMiner
  class Attribute
    attr_accessor :klass, :name, :options_for_step, :affected_by_steps, :key_for_steps

    def initialize(klass, name)
      @klass = klass
      @name = name.to_sym
      @options_for_step = {}
      @affected_by_steps = []
      @key_for_steps = []
    end
    
    # polling questions
    def report_find_or_create(step)
      "Creates parents: #{klass}##{name} is set with #{reflection_klass(step)}.find_or_create_by_#{foreign_key(step)}" if wants_create?(step)
    end
    
    def report_unnatural_order(step)
      if  wants_inline_association? and
          reflection_klass(step) and
          step.configuration.classes.index(reflection_klass(step)) > step.configuration.classes.index(klass)
        "Unnatural order: #{klass} comes before #{reflection_klass(step)}, but it might need it to already be mined"
      end
    end

    def inspect
      "Attribute(#{klass}.#{name})"
    end

    def affected_by!(step, options = {})
      self.options_for_step[step] = options
      self.affected_by_steps << step
    end

    def affected_by?(step)
      affected_by_steps.include?(step)
    end

    def key_for!(step, options = {})
      self.options_for_step[step] = options
      self.key_for_steps << step
    end

    def key_for?(step)
      key_for_steps.include?(step)
    end
    
    def value_in_dictionary(step, key)
      return *dictionary(step).lookup(key) # strip the array wrapper if there's only one element
    end
    
    def value_in_source(step, row)
      if wants_static?(step)
        value = static(step)
      elsif field_number(step)
        if field_number(step).is_a?(Range)
          value = field_number(step).map { |n| row[n] }.join(delimiter(step))
        else
          value = row[field_number(step)]
        end
      else
        value = row[name_in_source(step)]
      end
      return nil if value.nil?
      return value if value.is_a?(ActiveRecord::Base) # escape valve for parsers that look up associations directly
      value = value.to_s
      value = value[keep(step)] if wants_keep?(step)
      value = do_split(step, value) if wants_split?(step)
      # taken from old errata... maybe we want to do this here
      value.gsub!(/[ ]+/, ' ')
      # text.gsub!('- ', '-')
      value.gsub!(/([^\\])~/, '\1 ')
      value.strip!
      value.upcase! if wants_upcase?(step)
      value = do_convert(step, row, value) if wants_conversion?(step)
      value = do_sprintf(step, value) if wants_sprintf?(step)
      value
    end
    
    def value_from_row(step, row)
      value = value_in_source(step, row)
      return value if value.is_a?(ActiveRecord::Base) # carry through trapdoor
      value = value_in_dictionary(step, value) if wants_dictionary?(step)
      value = value_as_association(step, value) if wants_inline_association?
      value
    end
    
    def value_as_association(step, value)
      @_value_as_association ||= {}
      @_value_as_association[step] ||= {}
      if !@_value_as_association[step].has_key?(value)
        dynamic_matcher = wants_create?(step) ? "find_or_create_by_#{foreign_key(step)}" : "find_by_#{foreign_key(step)}"
        @_value_as_association[step][value] = reflection_klass(step).send(dynamic_matcher, value)
      end
      @_value_as_association[step][value]
    end
    
    # this will overwrite nils, even if wants_overwriting?(step) is false
    def set_record_from_row(step, record, row)
      return if !wants_overwriting?(step) and !record.send(name).nil?
      value = value_from_row(step, row)
      record.send "#{name}=", value
      $stderr.puts("ActiveRecord didn't like trying to set #{klass}.#{name} = #{value}") if !value.nil? and record.send(name).nil?
    end

    def perform(step)
      case step.variant
      when :associate
        perform_association(step)
      when :derive
        if wants_update_all?(step)
          perform_update_all(step)
        elsif wants_weighted_average?(step)
          perform_weighted_average(step)
        else
          perform_callback(step)
        end
      when :import
        raise "This shouldn't be called, the import step is special"
      end
    end

    def perform_association(step)
      raise "dictionary and prefix don't mix" if wants_dictionary?(step) and wants_prefix?(step)
      klass.update_all("#{reflection.primary_key_name} = NULL") if wants_nullification?(step)
      if wants_create?(step)
        klass.find_in_batches do |batch|
          batch.each do |record|
            if wants_prefix?(step)
              sql = "SELECT reflection_table.id FROM #{reflection_klass(step).quoted_table_name} AS reflection_table INNER JOIN #{klass.quoted_table_name} AS klass_table ON LEFT(klass_table.#{key(step)}, LENGTH(reflection_table.#{foreign_key(step)})) = reflection_table.#{foreign_key(step)} WHERE klass_table.id = #{record.id} ORDER BY LENGTH(reflection_table.#{foreign_key(step)}) DESC"
              associated_id = ActiveRecord::Base.connection.select_value(sql)
              next if associated_id.blank?
              record.send("#{reflection.primary_key_name}=", associated_id)
            else
              dynamic_finder_value = record.send(key(step))
              dynamic_finder_value = value_in_dictionary(step, dynamic_finder_value) if wants_dictionary?(step)
              next if dynamic_finder_value.blank?
              associated = reflection_klass(step).send("find_or_create_by_#{foreign_key(step)}", dynamic_finder_value) # TODO cache results
              record.send("#{name}=", associated)
            end
            record.save
          end
        end
      else
        reflection_klass(step).find_in_batches do |batch|
          batch.each do |reflection_record|
            klass.update_all ["#{reflection.primary_key_name} = ?", reflection_record.id], ["#{key(step)} = ?", reflection_record.send(foreign_key(step))]
          end
        end
      end
    end

    def perform_update_all(step)
      klass.update_all("#{name} = #{set(step)}", conditions(step))
    end
    
    def perform_weighted_average(step)
      # handle weighting by scopes instead of associations
      if weighting_association(step) and !klass.reflect_on_association(weighting_association(step))
        klass.find_in_batches do |batch|
          batch.each do |record|
            record.send "#{name}=", record.send(weighting_association(step)).weighted_average(name, :by => weighting_column(step), :disaggregator => weighting_disaggregator(step))
            record.save
          end
        end
      else # there's no weighting association OR there is one and it's a valid association
        klass.update_all_weighted_averages name, :by => weighting_column(step), :disaggregator => weighting_disaggregator(step), :association => weighting_association(step)
      end
    end
    
    def perform_callback(step)
      case klass.method(callback(step)).arity
      when 0:
        klass.send(callback(step))
      when 1:
        klass.send(callback(step), name)
      when 2:
        klass.send(callback(step), name, options_for_step[step])
      end
    end
    
    def unit_from_source(step, row)
      row[unit_in_source(step)].to_s.strip.underscore.to_sym
    end
    
    def do_convert(step, row, value)
      from_unit = from(step) || unit_from_source(step, row)
      value.to_f.convert(from_unit, to(step))
    end
    
    def do_sprintf(step, value)
      if /\%[0-9\.]*f/.match(sprintf(step))
        value = value.to_f
      elsif /\%[0-9\.]*d/.match(sprintf(step))
        value = value.to_i
      end
      sprintf(step) % value
    end
    
    def do_split(step, value)
      pattern = split_options(step)[:pattern] || /\s+/ # default is split on whitespace
      keep = split_options(step)[:keep] || 0           # default is keep first element
      value.to_s.split(pattern)[keep].to_s
    end
  
    def column_type
      @column_type ||= klass.columns_hash[name.to_s].type
    end
    
    {
      :static => 'options_for_step[step].has_key?(:static)',
      :prefix => :prefix,
      :create => :create,
      :keep => :keep,
      :upcase => :upcase,
      :conversion => '!from(step).nil? or !unit_in_source(step).nil?',
      :sprintf => :sprintf,
      :dictionary => :dictionary_options,
      :split => :split_options,
      :update_all => :set,
      :nullification => 'nullify(step) != false',
      :overwriting => 'overwrite(step) != false',
      :weighted_average => '!weighting_association(step).nil? or !weighting_column(step).nil?'
    }.each do |name, condition|
      condition = "!#{condition}(step).nil?" if condition.is_a?(Symbol)
      eval <<-EOS
        def wants_#{name}?(step)
          #{condition}
        end
      EOS
    end
    
    {
      :name_in_source => { :default => :name,                           :stringify => true },
      :key            => { :default => :name,                           :stringify => true },
      :foreign_key    => { :default => 'key(step)',                     :stringify => true },
      :delimiter      => { :default => '", "' }
    }.each do |name, options|
      eval <<-EOS
        def #{name}(step)
          (options_for_step[step][:#{name}] || #{options[:default]})#{'.to_s' if options[:stringify]}
        end
      EOS
    end
    
    def reflection
      if @_reflection.nil?
        @_reflection = klass.reflect_on_association(name) || :missing
        reflection
      elsif @_reflection == :missing
        nil
      else
        @_reflection
      end
    end
    
    def reflection_klass(step)
      return nil unless reflection
      if reflection.options[:polymorphic]
        polymorphic_type(step).andand.constantize
      else
        reflection.klass
      end
    end
    
    def wants_inline_association?
      reflection.present?
    end
    
    def callback(step)
      (options_for_step[step][:callback] || "derive_#{name}").to_sym
    end

    def dictionary(step)
      raise "shouldn't ask for this" unless wants_dictionary?(step) # don't try to initialize if there are no dictionary options
      @dictionaries ||= {}
      @dictionaries[step] ||= Dictionary.new(dictionary_options(step))
    end
    
    %w(dictionary split).each do |name|
      eval <<-EOS
        def #{name}_options(step)
          options_for_step[step][:#{name}]
        end
      EOS
    end
        
    %w(from to set conditions weighting_association weighting_column weighting_disaggregator sprintf nullify overwrite upcase prefix unit_in_source field_number keep create static polymorphic_type).each do |name|
      eval <<-EOS
        def #{name}(step)
          options_for_step[step][:#{name}]
        end
      EOS
    end
  end
end
