module DataMiner
  class AttributeCollection
    attr_accessor :klass, :attributes
    
    def initialize(klass)
      @klass = klass
      @attributes = {}
    end

    def key!(step, attr_name, attr_options = {})
      find_or_initialize(attr_name).key_for!(step, attr_options)
    end

    def affect!(step, attr_name, attr_options = {})
      find_or_initialize(attr_name).affected_by!(step, attr_options)
    end
    
    def affect_all_content_columns!(step, options = {})
      except = Array.wrap(options[:except]).map(&:to_sym)
      step.klass.content_columns.map(&:name).reject { |content_column| except.include?(content_column.to_sym) }.each do |content_column|
        find_or_initialize(content_column).affected_by!(step)
      end
    end

    def all_affected_by(step)
      attributes.values.find_all { |attr| attr.affected_by?(step) }
    end

    def all_keys_for(step)
      attributes.values.find_all { |attr| attr.key_for?(step) }
    end
    
    def all_for(step)
      (all_affected_by(step) + all_keys_for(step)).uniq
    end
    
    def has_keys_for?(step)
      attributes.values.any? { |attr| attr.key_for?(step) }
    end
    
    def has_conditional_writes_for?(step)
      all_affected_by(step).any? { |attr| !attr.wants_overwriting?(step) }
    end
    
    private
    
    def find_or_initialize(attr_name)
      self.attributes[attr_name] ||= Attribute.new(klass, attr_name)
    end
  end
end
