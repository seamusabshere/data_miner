class DataMiner
  # The container that holds each step in the script.
  class Script
    class << self
      # @private
      # activerecord-3.2.3/lib/active_record/scoping.rb
      def uniq
        previous_uniq = current_uniq
        Script.current_uniq = true
        begin
          yield
        ensure
          Script.current_uniq = previous_uniq
        end
      end

      # @private
      def current_stack
        ::Thread.current[STACK_THREAD_VAR] ||= []
      end

      # @private
      def current_stack=(stack)
        ::Thread.current[STACK_THREAD_VAR] = stack
      end

      # @private
      def current_uniq
        ::Thread.current[UNIQ_THREAD_VAR]
      end

      # @private
      def current_uniq=(uniq)
        ::Thread.current[UNIQ_THREAD_VAR] = uniq
      end
    end

    UNIQ_THREAD_VAR = 'DataMiner::Script.current_uniq'
    STACK_THREAD_VAR = 'DataMiner::Script.current_stack'

    # @private
    attr_reader :model

    # The steps in the script.
    # @return [Array<DataMiner::Step>]
    attr_reader :steps

    # @private
    def initialize(model)
      DataMiner.model_names.add model.name
      @model = model
      @steps = []
    end

    # @private
    def append_block(blk)
      instance_eval(&blk)
    end

    # Identify a single method or a define block of arbitrary code to be executed.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Step::Process The actual Process class.
    #
    # @overload process(method_id)
    #   Run a class method on the model.
    #   @param [Symbol] method_id The class method to be run on the model.
    #
    # @overload process(description, &blk)
    #   Run a block of code.
    #   @param [String] description A description of what the block does.
    #   @yield [] The block to be evaluated in the context of the model (it's instance_eval'ed on the model class)
    #
    # @example Single class method
    #   data_miner do
    #     [...]
    #     process :update_averages!
    #     [...]
    #   end
    #
    # @example Arbitrary code
    #   data_miner do
    #     [...]
    #     process "do some arbitrary stuff" do
    #       [...]
    #     end
    #     [...]
    #   end
    #
    # @return [nil]
    def process(method_id_or_description, &blk)
      append(:process, method_id_or_description, &blk)
    end

    # Import rows into your model.
    #
    # As long as...
    # 1. you +key+ on the primary key, or
    # 2. the table has an auto-increment primary key, or
    # 3. you DON'T enable +:validate+
    # ... then things will be sped up using the {https://github.com/seamusabshere/upsert upsert library} in streaming mode.
    #
    # Otherwise, native +ActiveRecord+ constuctors and validations will be used.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Step::Import The actual Import class.
    #
    # @param [String] description A description of the data source.
    # @param [Hash] settings Settings, including URL of the data source, that are used to download/parse (using RemoteTable) and (sometimes) correct (using Errata) the data.
    # @option settings [String] :url The URL of the data source. Passed directly to +RemoteTable.new+.
    # @option settings [Hash] :errata The +:responder+ and +:url+ settings that will be passed to +Errata.new+.
    # @option settings [TrueClass,FalseClass] :validate Whether to always run +ActiveRecord+ validations.
    # @option settings [*] anything Any other setting will be passed to +RemoteTable.new+.
    #
    # @yield [] A block defining how to +key+ the import (to make it idempotent) and which columns to +store+.
    #
    # @note Be sure to check out https://github.com/seamusabshere/remote_table and https://github.com/seamusabshere/errata for available +settings+.
    # @note There are hundreds of +import+ examples in https://github.com/brighterplanet/earth. The {file:README.markdown README} points to a few (at the bottom.)
    # @note We often use string primary keys to make idempotency easier. https://github.com/seamusabshere/active_record_inline_schema supports defining these inline.
    # @note Enabling +:validate+ may slow down importing large files because it precludes bulk loading using https://github.com/seamusabshere/upsert.
    #
    # @example From the README
    #   data_miner do
    #     [...]
    #     import("OpenGeoCode.org's Country Codes to Country Names list",
    #            :url => 'http://opengeocode.org/download/countrynames.txt',
    #            :format => :delimited,
    #            :delimiter => '; ',
    #            :headers => false,
    #            :skip => 22) do
    #       key   :iso_3166_code, :field_number => 0
    #       store :iso_3166_alpha_3_code, :field_number => 1
    #       store :iso_3166_numeric_code, :field_number => 2
    #       store :name, :field_number => 5
    #     end
    #     [...]
    #   end
    #
    # @return [nil]
    def import(description, settings, &blk)
      append(:import, description, settings, &blk)
    end

    # Execute SQL, provided either as a string or a URL.
    #
    # @see DataMiner::ActiveRecordClassMethods#data_miner Overview of how to define data miner scripts inside of ActiveRecord models.
    # @see DataMiner::Step::Sql The actual Sql class.
    #
    # @note +url_or_statement+ is auto-detected by looking for +%r{^[^\s]*/[^\*]}+ (non-spaces followed by a slash followed by non-asterisk). Therefore if you're passing a local file path and want it to be treated like a URL, make it absolute.
    #
    # @param [String] description What this step does.
    # @param [String] url_or_statement SQL statement as a String or location of the SQL file as a URL.
    #
    # @example Rapidly get a list of countries from Brighter Planet's Reference Data web service
    #   data_miner do
    #     sql "Brighter Planet's countries", 'http://data.brighterplanet.com/countries.sql'
    #   end
    def sql(description, url_or_statement)
      append(:sql, description, url_or_statement)
    end

    # Prepend a step to a script unless it's already there. Mostly for internal use.
    #
    # @return [nil]
    def prepend_once(*args, &blk)
      step = make(*args, &blk)
      unless steps.include? step
        steps.unshift step
      end
      nil
    end

    # Prepend a step to a script. Mostly for internal use.
    #
    # @return [nil]
    def prepend(*args, &blk)
      steps.unshift make(*args, &blk)
      nil
    end

    # Append a step to a script unless it's already there. Mostly for internal use.
    #
    # @return [nil]
    def append_once(*args, &blk)
      step = make(*args, &blk)
      unless steps.include? step
        steps << step
      end
      nil
    end

    # Append a step to a script. Mostly for internal use.
    #
    # @return [nil]
    def append(*args, &blk)
      steps << make(*args, &blk)
      nil
    end

    # Run the script for this model. Mostly for internal use.
    #
    # @note Normally you should use +Country.run_data_miner!+
    # @note A primitive "call stack" is kept that will prevent infinite loops. So, if Country's data miner script calls Province's AND vice-versa, each one will only be run once.
    #
    # @return [DataMiner::Run]
    def start
      model_name = model.name
      # $stderr.write "0 - #{model_name}\n"
      # $stderr.write "A - current_uniq - #{Script.current_uniq ? 'true' : 'false'}\n"
      # $stderr.write "B - #{Script.current_stack.join(',')}\n"
      if Script.current_uniq and Script.current_stack.include?(model_name)
        # we've already done this in the current stack, so skip it
        return
      end
      if not Script.current_uniq
        # since we're not trying to uniq, ignore the current contents of the stack
        Script.current_stack.clear
      end
      Script.current_stack << model_name
      unless Run.table_exists?
        Run.auto_upgrade!
      end
      run = Run.new
      run.model_name = model_name
      run.start do
        steps.each do |step|
          step.start
          model.reset_column_information
        end
      end
    end
        
    private

    # return [DataMiner::Step]
    def make(*args, &blk)
      klass = Step.const_get(args.shift.to_s.camelcase)
      options = args.extract_options!
      if args.empty?
        args = ["#{klass.name.demodulize} step with no description"]
      end
      initializer = [self] + args + [options]
      if block_given?
        klass.new(*initializer, &blk)
      else
        klass.new(*initializer)
      end
    end
  end
end
