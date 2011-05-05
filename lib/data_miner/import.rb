require 'blockenspiel'
require 'errata'
require 'remote_table'
class DataMiner
  class Import
    include ::Blockenspiel::DSL
    
    attr_reader :attributes
    attr_reader :config
    attr_reader :options
    attr_reader :description
    
    def initialize(config, description, options = {})
      @config = config
      @description = description
      @options = options.dup
      @options.stringify_keys!
      # legacy
      if @options.has_key? 'table'
        ::DataMiner.logger.info "Warning: 'table' is no longer an allowed option, taking the url from it and ignoring the rest"
        table_instance = @options.delete 'table'
        @options['url'] = table_instance.url
      end
      # legacy
      if @options.has_key?('errata') and not @options['errata'].is_a?(::Hash)
        ::DataMiner.logger.info "Warning: 'errata' must be a hash of Errata options. taking the URL from the Errata instance you provided and ignoring everything else"
        errata_instance = @options.delete 'errata'
        @options['errata'] = { 'url' => errata_instance.options['url'] }
      end
    end
        
    def attributes
      @attributes ||= ::ActiveSupport::OrderedHash.new
    end
    
    def resource
      config.resource
    end

    def inspect
      %{#<DataMiner::Import(#{resource}) #{description}>}
    end
    
    def store(attr_name, attr_options = {})
      raise "You should only call store or key once for #{resource.name}##{attr_name}" if attributes.has_key? attr_name
      attributes[attr_name] = Attribute.new self, attr_name, attr_options
    end
    
    def key(attr_name, attr_options = {})
      raise "You should only call store or key once for #{resource.name}##{attr_name}" if attributes.has_key? attr_name
      @_key = attr_name
      store attr_name, attr_options
    end

    def primary_key
      resource.primary_key
    end

    def table
      return @table if @table.is_a? ::RemoteTable
      # don't mess with the originals
      options = @options.dup
      options['streaming'] = true
      if options['errata']
        errata_options = options['errata'].dup
        errata_options.stringify_keys!
        errata_options['responder'] ||= resource
        options['errata'] = errata_options
      end
      @table = ::RemoteTable.new options
    end

    def free
      attributes.each { |_, attr| attr.free }
      @table.free if @table.is_a?(::RemoteTable)
      @table = nil
    end
    
    def run
      table.each do |row|
        record = resource.send "find_or_initialize_by_#{@_key}", attributes[@_key].value_from_row(row)
        attributes.each { |_, attr| attr.set_record_from_row record, row }
        if record.send(primary_key).present?
          record.save!
        else
          ::DataMiner.logger.debug "Skipping #{row} because there's no primary key"
        end
      end
      free
      nil
    end
  end
end
