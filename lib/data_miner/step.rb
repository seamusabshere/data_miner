module DataMiner
  class Step
    attr_accessor :configuration, :number, :options
    delegate :klass, :to => :configuration
    delegate :attributes, :to => :configuration

    def initialize(configuration, number, options = {}, &block)
      @configuration = configuration
      @number = number
      @options = options
      yield self if block_given? # pull in attributes
      attributes.affect_all_content_columns!(self, :except => options[:except]) if options[:affect_all] == :content_columns
      affected_attributes.each { |attr| attr.options_for_step[self][:callback] = options[:callback] } if options[:callback]
      all_attributes.each { |attr| attr.options_for_step[self][:name_in_source] = attr.name_in_source(self).upcase } if options[:headers] == :upcase # TODO remove
    end
    
    def variant
      self.class.name.demodulize.underscore.to_sym
    end
    
    def awaiting?
      !options[:awaiting].nil?
    end
    
    def inspect
      "Step(#{klass} #{variant.to_s.camelcase} #{number})"
    end
    
    def signature
      "#{klass} step #{number}: #{variant}"
    end
    
    def perform(options = {})
      return if awaiting? and !options[:force]
      affected_attributes.each { |attr| attr.perform self }
      $stderr.puts "performed #{signature}"
    end
    
    def affected_attributes
      @affected_attributes ||= attributes.all_affected_by self
    end
    
    def key_attributes
      @key_attributes ||= attributes.all_keys_for self
    end
    
    def all_attributes
      @all_attributes ||= attributes.all_for self
    end

    def key(attr_name, attr_options = {})
      attributes.key! self, attr_name, attr_options
    end

    def affect(attr_name, attr_options = {})
      attributes.affect! self, attr_name, attr_options
    end
    alias_method :store, :affect 
    
    def map_to_attrs(method)
      affected_attributes.map { |attr| attr.send method, self }.compact
    end
  end
end
