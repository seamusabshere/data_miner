require 'csv'
require 'tmpdir'
require 'posix/spawn'
require 'unix_utils'

class DataMiner
  class Step
    # A step that executes a SQL, either from a string or as retrieved from a URL.
    #
    # Create these by calling +sql+ inside a +data_miner+ block.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Script#sql Creating a sql step by calling DataMiner::Script#sql from inside a data miner script
    class Sql < Step
      URL_DETECTOR = %r{^[^\s]*/[^\*]}

      # Description of what this step does.
      # @return [String]
      attr_reader :description

      # Location of the SQL file.
      # @return [String]
      attr_reader :url

      # String containing the SQL.
      # @return [String]
      attr_reader :statement
      
      # @private
      def initialize(script, description, url_or_statement, ignored_options = nil)
        @script = script
        @description = description
        if url_or_statement =~ URL_DETECTOR
          @url = url_or_statement
        else
          @statement = url_or_statement
        end
      end

      # @private
      def start
        if statement
          c = ActiveRecord::Base.connection_pool.checkout
          c.execute statement
          ActiveRecord::Base.connection_pool.checkin c
        else
          tmp_path = UnixUtils.curl url
          send config[:adapter], tmp_path
          File.unlink tmp_path
        end
      end

      private

      def config
        if ActiveRecord::Base.respond_to?(:connection_config)
          ActiveRecord::Base.connection_config
        else
          ActiveRecord::Base.connection_pool.spec.config
        end
      end

      def mysql(path)
        connect = if config[:socket]
          [ '--socket', config[:socket] ]
        else
          [ '--host', config.fetch(:host, '127.0.0.1'), '--port', config.fetch(:port, 3306).to_s ]
        end
        
        argv = [
          'mysql',
          '--compress',
          '--user', config[:username],
          "-p#{config[:password]}",
          connect,
          '--default-character-set', 'utf8',
          config[:database]
        ].flatten

        File.open(path) do |f|
          pid = POSIX::Spawn.spawn(*(argv+[{:in => f}]))
          ::Process.waitpid pid
        end
        unless $?.success?
          raise RuntimeError, "[data_miner] Failed: ARGV #{argv.join(' ').inspect}"
        end
        nil
      end

      alias :mysql2 :mysql

      def postgresql(path)
        env = {}
        env['PGHOST']     = config['host']          if config['host']
        env['PGPORT']     = config['port'].to_s     if config['port']
        env['PGPASSWORD'] = config['password'].to_s if config['password']
        env['PGUSER']     = config['username'].to_s if config['username']

        argv = [
          'psql',
          '--quiet',
          '--dbname', config[:database],
          '--file',   path
        ].flatten
        
        child = POSIX::Spawn::Child.new(*([env]+argv))
        $stderr.puts child.out
        $stderr.puts child.err
        unless child.success?
          raise RuntimeError, "[data_miner] Failed: ENV #{env.inspect} ARGV #{argv.join(' ').inspect} (#{child.err.inspect})"
        end
        nil
      end

      def sqlite3(path)
        argv = [
          'sqlite3',
          config[:database]
        ]
        File.open(path) do |f|
          pid = POSIX::Spawn.spawn(*(argv+[{:in => f}]))
          ::Process.waitpid pid
        end
        unless $?.success?
          raise RuntimeError, %{[data_miner] Failed: "cat #{path} | #{argv.join(' ')}"}
        end
        nil
      end
    end
  end
end
