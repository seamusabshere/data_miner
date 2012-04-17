require 'errata'
require 'remote_table'

class DataMiner::Step::Import
  attr_reader :attributes
  attr_reader :config
  attr_reader :description
  attr_reader :attributes
  
  def initialize(config, description, options = {}, &blk)
    options = options.symbolize_keys
    if options.has_key?(:table)
      raise ::ArgumentError, %{[data_miner] :table is no longer an allowed option.}
    end
    if (errata_options = options[:errata]) and not errata_options.is_a?(::Hash)
      raise ::ArgumentError, %{[data_miner] :errata must be a hash of initialization options to Errata}
    end
    @config = config
    @mutex = ::Mutex.new
    @attributes = ::ActiveSupport::OrderedHash.new
    @description = description
    if options.has_key? :errata
      errata_options = options[:errata].symbolize_keys
      errata_options[:responder] ||= model
      options[:errata] = errata_options
    end
    @table_options = options.dup
    @table_options[:streaming] = true
    instance_eval(&blk)
  end

  def model
    config.model
  end

  def store(attr_name, attr_options = {})
    attr_name = attr_name.to_sym
    if attributes.has_key? attr_name
      raise "You should only call store or key once for #{model.name}##{attr_name}"
    end
    attributes[attr_name] = DataMiner::Attribute.new self, attr_name, attr_options
  end
  
  def key(attr_name, attr_options = {})
    attr_name = attr_name.to_sym
    if attributes.has_key? attr_name
      raise "You should only call store or key once for #{model.name}##{attr_name}"
    end
    @key = attr_name
    store attr_name, attr_options
  end

  def table
    @table || @mutex.synchronize do
      @table ||= ::RemoteTable.new(@table_options)
    end
  end

  def free
    @table = nil
  end
  
  def perform
    table.each do |row|
      record = model.send "find_or_initialize_by_#{@key}", attributes[@key].read(row)
      attributes.each { |_, attr| attr.set_from_row record, row }
      begin
        record.save!
      rescue
        a = 1
        debugger
        a = 1
      end
    end
    free
    nil
  end
end
