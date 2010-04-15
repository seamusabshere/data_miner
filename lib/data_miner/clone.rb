module DataMiner
  class Clone
    attr_accessor :configuration
    attr_accessor :position_in_run
    attr_accessor :description
    attr_accessor :options
    delegate :resource, :to => :configuration

    def initialize(configuration, position_in_run, description, options = {})
      DataMiner.log_or_raise "Clone has to be the first step." unless position_in_run == 0
      DataMiner.log_or_raise "Clone needs :url" unless options[:url].present?
      @configuration = configuration
      @position_in_run = position_in_run
      @description = description
      @options = options
    end
    
    def inspect
      "Clone(#{resource}): #{description}"
    end
    
    def run(run)
      download_sql_source
      perform_sanity_check unless options[:sanity_check] == false
      execute_sql_source
      DataMiner.log_info "ran #{inspect}"
    end
    
    private
    
    # from remote_table
    def tempfile_path    
      return @_tempfile_path if @_tempfile_path
      @_tempfile_path = Tempfile.open(options[:url].gsub(/[^a-z0-9]+/i, '_')[0,100]).path
      FileUtils.rm_f @_tempfile_path
      at_exit { FileUtils.rm_rf @_tempfile_path }
      @_tempfile_path
    end
    
    def download_sql_source
      cmd = %{
        curl \
        --silent \
        --header "Expect: " \
        --location \
        "#{options[:url]}" \
        --output "#{tempfile_path}"
      }
      `#{cmd}`
    end

    def perform_sanity_check
      File.open(tempfile_path, 'r') do |infile|
        while (line = infile.gets)
          line_essence = line.gsub /[^\-\_\.a-zA-Z0-9]+/, ' '
          if line_essence =~ /(INSERT\s+INTO|CREATE\s+TABLE|ALTER\s+TABLE|DROP\s+TABLE\s+[^I]|DROP\s+TABLE\s+IF\s+EXISTS)\s+([^\s]+)/i
            one = $1
            two = $2
            unless two.split('.').last == resource.table_name
              DataMiner.log_or_raise %{

Warning: clone SQL tries to #{one} on `#{two}` instead of `#{resource.table_name}`. (#{line[0,100]}...)

If you want to ignore this, use clone 'X', :url => 'Y', :sanity_check => false

If you need to set a different table name, you could say set_table_name '#{two}' in your ActiveRecord model.
              }
            end
          end
        end
      end
    end

    def execute_sql_source
      mysql_config = ActiveRecord::Base.connection.instance_variable_get :@config
      cmd = %{
        mysql                                   \
        --batch                                 \
        #{"--host=\"#{mysql_config[:hostname]}\"" if mysql_config[:hostname].present?} \
        --user="#{mysql_config[:username]}"     \
        --password="#{mysql_config[:password]}" \
        --database="#{mysql_config[:database]}" \
        --execute="SOURCE #{tempfile_path}"
      }
      `#{cmd}`
    end
  end
end
