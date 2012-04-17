require 'uri'
# Note that you probably shouldn't put taps into your Gemfile, because it depends on sequel and other gems that may not compile on Heroku (etc.)
#
# This class automatically detects if you have Bundler installed, and if so, executes the `taps` binary with a "clean" environment (i.e. one that will not pay attention to the fact that taps is not in your Gemfile)
class DataMiner::Step::Tap
  DEFAULT_PORTS = {
    :mysql => 3306,
    :mysql2 => 3306,
    :postgres => 5432
  }
  
  DEFAULT_USERNAMES = {
    :mysql => 'root',
    :mysql2 => 'root',
    :postgres => ''
  }
  
  DEFAULT_PASSWORDS = {}
  DEFAULT_PASSWORDS.default = ''
  
  DEFAULT_HOSTS = {}
  DEFAULT_HOSTS.default = '127.0.0.1'

  attr_reader :config
  attr_reader :description
  attr_reader :source
  attr_reader :database_options
  attr_reader :source_table_name

  def initialize(config, description, source, options = {})
    options = options.symbolize_keys
    @config = config
    @description = description
    @source = source
    @database_options = options.except(:source_table_name).reverse_merge(connection.instance_variable_get(:@config).symbolize_keys)
    @source_table_name = options.fetch :source_table_name, model.table_name
  end
  
  def model
    config.model
  end
  
  def perform
    [ source_table_name, model.table_name ].each do |possible_obstacle|
      if connection.table_exists? possible_obstacle
        connection.drop_table possible_obstacle
      end
    end
    taps_pull
    if needs_table_rename?
      connection.rename_table source_table_name, model.table_name
    end
    nil
  end
  
  # sabshere 1/25/11 what if there were multiple connections
  # blockenspiel doesn't like to delegate this to #model
  def connection
    ::ActiveRecord::Base.connection
  end
  
  def needs_table_rename?
    source_table_name != model.table_name
  end
  
  def adapter
    case connection.adapter_name
    when /mysql2/i
      'mysql2'
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
    database_options[:database]
  end
  
  %w{ username password port host }.each do |x|
    module_eval %{
      def #{x}
        database_options[:#{x}] || DEFAULT_#{x.upcase}S[adapter.to_sym]
      end
    }
  end
  
  # "user:pass"
  # "user"
  # nil
  def userinfo
    if username.present?
      [username, password].select(&:present?).join(':')
    end
  end
  
  def db_url
    case adapter
    when 'sqlite'
      "sqlite://#{database}"
    else
      ::URI::Generic.new(adapter, userinfo, host, port, nil, "/#{database}", nil, nil, nil).to_s
    end
  end
  
  def taps_pull
    args = [
      'taps',
      'pull',
      db_url,
      source,
      '--indexes-first',
      '--tables',
      source_table_name
    ]
    
    # https://github.com/carlhuda/bundler/issues/1579
    if defined?(::Bundler)
      ::Bundler.with_clean_env do
        ::Kernel.system args.join(' ')
      end
    else
      ::Kernel.system args.join(' ')
    end
  end
end
