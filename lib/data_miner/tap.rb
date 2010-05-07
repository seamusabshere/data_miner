
module DataMiner
  class Tap
    attr_reader :configuration
    attr_reader :position_in_run
    attr_reader :description
    attr_reader :source
    attr_reader :options
    delegate :resource, :to => :configuration

    def initialize(configuration, position_in_run, description, source, options = {})
      options.symbolize_keys!
      DataMiner.log_or_raise "Tap has to be the first step." unless position_in_run == 0
      @configuration = configuration
      @position_in_run = position_in_run
      @description = description
      @source = source
      @options = options
    end
    
    def inspect
      "Tap(#{resource}): #{description} (#{source})"
    end
    
    def run(run)
      [ source_table_name, resource.table_name ].each do |possible_obstacle|
        if connection.table_exists?(possible_obstacle)
          connection.drop_table possible_obstacle
        end
      end
      DataMiner.backtick_with_reporting taps_pull_cmd
      if needs_table_rename?
        connection.rename_table source_table_name, resource.table_name
      end
      DataMiner.log_info "ran #{inspect}"
    end
    
    private
    
    def connection
      ActiveRecord::Base.connection
    end
    
    def db_config
      @_db_config ||= connection.instance_variable_get(:@config).dup.merge(options.except(:source_table_name))
    end
    
    def source_table_name
      options[:source_table_name] || resource.table_name
    end
    
    def needs_table_rename?
      source_table_name != resource.table_name
    end
    
    def adapter
      case connection.adapter_name
      when /mysql/i
        'mysql'
      when /postgres/i
        'postgres'
      when /sqlite/i
        'sqlite'
      end
    end

    # never optional
    def database
      db_config[:database]
    end
    
    DEFAULT_PORTS = {
      'mysql' => 3306,
      'postgres' => 5432
    }
    
    DEFAULT_USERNAMES = {
      'mysql' => 'root',
      'postgres' => ''
    }
    
    DEFAULT_PASSWORDS = {}
    DEFAULT_PASSWORDS.default = ''
    
    DEFAULT_HOSTS = {}
    DEFAULT_HOSTS.default = 'localhost'

    %w{ username password port host }.each do |x|
      module_eval %{
        def #{x}
          db_config[:#{x}] || DEFAULT_#{x.upcase}S[adapter]
        end
      }
    end
    
    def db_locator
      case adapter
      when 'mysql', 'postgres'
        "#{username}:#{password}@#{host}:#{port}/#{database}"
      when 'sqlite'
        database
      end
    end
    
    # taps pull mysql://root:password@localhost/taps_test http://foo:bar@data.brighterplanet.com:5000 --tables aircraft
    def taps_pull_cmd
      "taps pull #{adapter}://#{db_locator} #{source} --tables #{source_table_name}"
    end
    
    # 2.3.5 mysql
    # * <tt>:host</tt> - Defaults to "localhost".
    # * <tt>:port</tt> - Defaults to 3306.
    # * <tt>:socket</tt> - Defaults to "/tmp/mysql.sock".
    # * <tt>:username</tt> - Defaults to "root"
    # * <tt>:password</tt> - Defaults to nothing.
    # * <tt>:database</tt> - The name of the database. No default, must be provided.
    # * <tt>:encoding</tt> - (Optional) Sets the client encoding by executing "SET NAMES <encoding>" after connection.
    # * <tt>:reconnect</tt> - Defaults to false (See MySQL documentation: http://dev.mysql.com/doc/refman/5.0/en/auto-reconnect.html).
    # * <tt>:sslca</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslkey</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcert</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcapath</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcipher</tt> - Necessary to use MySQL with an SSL connection.
    # 2.3.5 mysql
    # * <tt>:host</tt> - Defaults to "localhost".
    # * <tt>:port</tt> - Defaults to 5432.
    # * <tt>:username</tt> - Defaults to nothing.
    # * <tt>:password</tt> - Defaults to nothing.
    # * <tt>:database</tt> - The name of the database. No default, must be provided.
    # * <tt>:schema_search_path</tt> - An optional schema search path for the connection given as a string of comma-separated schema names.  This is backward-compatible with the <tt>:schema_order</tt> option.
    # * <tt>:encoding</tt> - An optional client encoding that is used in a <tt>SET client_encoding TO <encoding></tt> call on the connection.
    # * <tt>:min_messages</tt> - An optional client min messages that is used in a <tt>SET client_min_messages TO <min_messages></tt> call on the connection.
    # * <tt>:allow_concurrency</tt> - If true, use async query methods so Ruby threads don't deadlock; otherwise, use blocking query methods.
    # 2.3.5 sqlite[3]
    # * <tt>:database</tt> - Path to the database file.
  end
end
