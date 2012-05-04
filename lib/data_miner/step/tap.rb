require 'uri'

class DataMiner
  class Step
    # A step that uses https://github.com/ricardochimal/taps to import table structure and data.
    #
    # Create these by calling +tap+ inside a +data_miner+ block.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Script#tap
    class Tap < Step
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

      # @private
      attr_reader :script

      # A description of the tapped data source.
      # @return [String]
      attr_reader :description

      # The URL of the tapped data source, including username, password, domain, and port number.
      # @return [String]
      attr_reader :source

      # Connection options that will be passed to the +taps pull command+. Defaults to the ActiveRecord connection config, if available.
      # @return [Hash]
      attr_reader :database_options

      # Source table name. Defaults to the table name of the model.
      # @return [String]
      attr_reader :source_table_name

      # @private
      def initialize(script, description, source, options = {})
        options = options.symbolize_keys
        @script = script
        @description = description
        @source = source
        @source_table_name = options.delete(:source_table_name) || model.table_name
        @database_options = options.reverse_merge script.model.connection.instance_variable_get(:@config).symbolize_keys
      end
      
      # @private
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
      
      # @return [String] The name of the current database.
      def database
        unless database = database_options[:database]
          raise ::ArgumentError, %{[data_miner] Can't infer database name from options or ActiveRecord config.}
        end
        database
      end
      
      # @return [String] The database username.
      def username
        database_options[:username] || DEFAULT_USERNAMES[adapter.to_sym]
      end

      # @return [String] The database password.
      def password
        database_options[:password] || DEFAULT_PASSWORDS[adapter.to_sym]
      end

      # @return [String] The database port number.
      def port
        database_options[:port] || DEFAULT_PORTS[adapter.to_sym]
      end

      # @return [String] The database hostname.
      def host
        database_options[:host] || DEFAULT_HOSTS[adapter.to_sym]
      end

      private

      def connection
        model.connection
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

      # Note that you probably shouldn't put taps into your Gemfile, because it depends on sequel and other gems that may not compile on Heroku (etc.)
      #
      # This class automatically detects if you have Bundler installed, and if so, executes the `taps` binary with a "clean" environment (i.e. one that will not pay attention to the fact that taps is not in your Gemfile)
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
  end
end
