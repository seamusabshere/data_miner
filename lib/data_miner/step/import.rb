require 'errata'
require 'remote_table'

class DataMiner::Step::Import
  attr_reader :attributes
  attr_reader :config
  attr_reader :options
  attr_reader :description
  attr_reader :attributes
  
  def initialize(config, description, options = {}, &blk)
    @config = config
    @attributes = ::ActiveSupport::OrderedHash.new
    @description = description
    @options = options.symbolize_keys
    # legacy
    if @options.has_key? :table
      DataMiner.logger.warn %{:table is no longer an allowed option, taking the url from it and ignoring the rest}
      table_instance = @options.delete :table
      @options[:url] = table_instance.url
    end
    # legacy
    if @options.has_key?(:errata) and not @options[:errata].is_a?(::Hash)
      DataMiner.logger.warn %{:errata must be a hash of Errata options. taking the URL from the Errata instance you provided and ignoring everything else}
      errata_instance = @options.delete :errata
      @options[:errata] = { :url => errata_instance.options[:url] }
    end
    instance_eval(&blk)
  end

  def model
    config.model
  end

  def inspect
    %{#<DataMiner::Import(#{model}) #{description}>}
  end
  
  def store(attr_name, attr_options = {})
    attr_name = attr_name.to_sym
    raise "You should only call store or key once for #{model.name}##{attr_name}" if attributes.has_key? attr_name
    attributes[attr_name] = DataMiner::Attribute.new self, attr_name, attr_options
  end
  
  def key(attr_name, attr_options = {})
    attr_name = attr_name.to_sym
    raise "You should only call store or key once for #{model.name}##{attr_name}" if attributes.has_key? attr_name
    @key = attr_name
    store attr_name, attr_options
  end

  def table
    @table ||= begin
      # don't mess with the originals
      options = @options.dup
      options[:streaming] = true
      if options[:errata]
        errata_options = options[:errata].symbolize_keys
        errata_options[:responder] ||= model
        options[:errata] = errata_options
      end
      ::RemoteTable.new options
    end
  end

  def free
    @table = nil
  end
  
  def perform
    table.each do |row|
      record = model.send "find_or_initialize_by_#{@key}", attributes[@key].value_from_row(row)
      attributes.each { |_, attr| attr.set_record_from_row record, row }
      begin
        record.save!
      rescue
        DataMiner.logger.warn "[data_miner] Got #{$!.inspect} when trying to save #{row}"
      end
    end
    free
    nil
  end
end
