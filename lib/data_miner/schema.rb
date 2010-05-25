module DataMiner
  class Schema
    include Blockenspiel::DSL
    
    attr_reader :configuration
    attr_reader :position_in_run
    attr_reader :create_table_options
    delegate :resource, :to => :configuration

    def initialize(configuration, position_in_run, create_table_options)
      @configuration = configuration
      @position_in_run = position_in_run
      @create_table_options = create_table_options
      @create_table_options.symbolize_keys!
      DataMiner.log_or_raise ":id => true is not allowed in create_table_options." if @create_table_options[:id] === true
      DataMiner.log_or_raise ":primary_key is not allowed in create_table_options. Use set_primary_key instead." if @create_table_options.has_key?(:primary_key)
      @create_table_options[:id] = false # always
    end
    
    def connection
      ActiveRecord::Base.connection
    end
    
    def table_name
      resource.table_name
    end
    
    def ideal_table
      @ideal_table ||= ActiveRecord::ConnectionAdapters::TableDefinition.new(connection)
    end
    
    def ideal_indexes
      @ideal_indexes ||= Array.new
    end
    
    def actual_indexes
      connection.indexes table_name
    end
    
    def description
      "Define a table called #{table_name} with primary key #{ideal_primary_key_name}"
    end
    
    def inspect
      "Schema(#{resource}): #{description}"
    end
    
    # lifted straight from activerecord-3.0.0.beta3/lib/active_record/connection_adapters/abstract/schema_definitions.rb
    %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |column_type|
      class_eval <<-EOV
        def #{column_type}(*args)                                               # def string(*args)
          options = args.extract_options!                                       #   options = args.extract_options!
          column_names = args                                                   #   column_names = args
                                                                                #
          column_names.each { |name| ideal_table.column(name, '#{column_type}', options) }  #   column_names.each { |name| ideal_table.column(name, 'string', options) }
        end                                                                     # end
      EOV
    end
    def column(*args)
      ideal_table.column(*args)
    end
    
    MAX_INDEX_NAME_LENGTH = 50
    def index(columns, options = {})
      options.symbolize_keys!
      columns = Array.wrap columns
      unless name = options[:name]
        default_name = connection.index_name(table_name, options.merge(:column => columns))
        name = default_name.length < MAX_INDEX_NAME_LENGTH ? default_name : default_name[0..MAX_INDEX_NAME_LENGTH-11] + Zlib.crc32(default_name).to_s
      end
      index_unique = options.has_key?(:unique) ? options[:unique] : true
      ideal_indexes.push ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, name, index_unique, columns)
    end
    
    def ideal_primary_key_name
      resource.primary_key.to_s
    end
    
    def actual_primary_key_name
      connection.primary_key(table_name).to_s
    end
        
    INDEX_PROPERTIES = %w{ name columns }
    def index_equivalent?(a, b)
      return false unless a and b
      INDEX_PROPERTIES.all? do |property|
        DataMiner.log_debug "...comparing #{a.send(property).inspect}.to_s <-> #{b.send(property).inspect}.to_s"
        a.send(property).to_s == b.send(property).to_s
      end
    end

    # FIXME mysql only (assume integer primary keys)
    def column_equivalent?(a, b)
      return false unless a and b
      a_type = a.type.to_s == 'primary_key' ? 'integer' : a.type.to_s
      b_type = b.type.to_s == 'primary_key' ? 'integer' : b.type.to_s
      a_type == b_type and a.name.to_s == b.name.to_s
    end

    %w{ column index }.each do |i|
      eval %{
        def #{i}_needs_to_be_placed?(name)
          actual = actual_#{i} name
          return true unless actual
          ideal = ideal_#{i} name
          not #{i}_equivalent? actual, ideal
        end
    
        def #{i}_needs_to_be_removed?(name)
          ideal_#{i}(name).nil?
        end
      }
    end
    
    def ideal_column(name)
      ideal_table[name.to_s]
    end
    
    def actual_column(name)
      resource.columns_hash[name.to_s]
    end
    
    def ideal_index(name)
      ideal_indexes.detect { |ideal| ideal.name == name.to_s }
    end
    
    def actual_index(name)
      actual_indexes.detect { |actual| actual.name == name.to_s }
    end
  
    def place_column(name)
      remove_column name if actual_column name
      ideal = ideal_column name
      DataMiner.log_debug "ADDING COLUMN #{name}"
      connection.add_column table_name, name, ideal.type.to_sym # symbol type!
      resource.reset_column_information
    end
    
    def remove_column(name)
      DataMiner.log_debug "REMOVING COLUMN #{name}"
      connection.remove_column table_name, name
      resource.reset_column_information
    end
    
    def place_index(name)
      remove_index name if actual_index name
      ideal = ideal_index name
      DataMiner.log_debug "ADDING INDEX #{name}"
      connection.add_index table_name, ideal.columns, :name => ideal.name
      resource.reset_column_information
    end
    
    def remove_index(name)
      DataMiner.log_debug "REMOVING INDEX #{name}"
      connection.remove_index table_name, :name => name
      resource.reset_column_information
    end
    
    def run(run)
      _add_extra_columns
      _create_table
      _set_primary_key
      _remove_columns
      _add_columns
      _remove_indexes
      _add_indexes
      DataMiner.log_debug "ran #{inspect}"
    end
    
    EXTRA_COLUMNS = {
      :updated_at => :datetime,
      :created_at => :datetime
    }
    def _add_extra_columns
      EXTRA_COLUMNS.each do |extra_name, extra_type|
        send extra_type, extra_name unless ideal_column extra_name
      end
    end
    
    def _create_table
      if not resource.table_exists?
        DataMiner.log_debug "CREATING TABLE #{table_name} with #{create_table_options.inspect}"
        connection.create_table table_name, create_table_options do |t|
          t.integer :data_miner_placeholder
        end
        resource.reset_column_information
      end
    end
    
    # FIXME mysql only
    def _set_primary_key
      if ideal_primary_key_name == 'id' and not ideal_column('id')
        DataMiner.log_debug "no special primary key set on #{table_name}, so using 'id'"
        column 'id', :primary_key
      end
      actual = actual_column actual_primary_key_name
      ideal = ideal_column ideal_primary_key_name
      if not column_equivalent? actual, ideal
        DataMiner.log_debug "looks like #{table_name} has a bad (or missing) primary key"
        if actual
          DataMiner.log_debug "looks like primary key needs to change from #{actual_primary_key_name} to #{ideal_primary_key_name}, re-creating #{table_name} from scratch"
          connection.drop_table table_name
          resource.reset_column_information
          _create_table
        end
        place_column ideal_primary_key_name
        DataMiner.log_debug "ADDING PRIMARY KEY #{ideal_primary_key_name}"
        connection.execute "ALTER TABLE `#{table_name}` ADD PRIMARY KEY (`#{ideal_primary_key_name}`)"
      end
      resource.reset_column_information
    end
    
    def _remove_columns
      resource.columns_hash.values.each do |actual|
        remove_column actual.name if column_needs_to_be_removed? actual.name
      end
    end
    
    def _add_columns
      ideal_table.columns.each do |ideal|
        place_column ideal.name if column_needs_to_be_placed? ideal.name
      end
    end
    
    def _remove_indexes
      actual_indexes.each do |actual|
        remove_index actual.name if index_needs_to_be_removed? actual.name
      end
    end
    
    def _add_indexes
      ideal_indexes.each do |ideal|
        next if ideal.name == ideal_primary_key_name # this should already have been taken care of
        place_index ideal.name if index_needs_to_be_placed? ideal.name
      end
    end
  end
end