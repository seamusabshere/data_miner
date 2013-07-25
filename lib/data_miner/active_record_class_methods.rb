require 'active_record'

class DataMiner
  # Class methods that are mixed into models (i.e. ActiveRecord::Base)
  module ActiveRecordClassMethods
    # Access this model's script.
    #
    # @return [DataMiner::Script] This model's data miner script.
    def data_miner_script
      @data_miner_script || ::Thread.exclusive do
        @data_miner_script ||= DataMiner::Script.new(self)
      end
    end
    
    # Run this model's script.
    #
    # @return nil
    def run_data_miner!
      data_miner_script.start
    end
    
    # Run the data miner scripts of parent associations. Useful for dependencies. Safe to call using +process+.
    #
    # @note Used extensively in https://github.com/brighterplanet/earth
    #
    # @example Since Provinces depend on Countries, make sure Countries are data mined first
    #   class Country < ActiveRecord::Base
    #     [...some data miner script...]
    #   end
    #   class Province < ActiveRecord::Base
    #     belongs_to :country
    #     data_miner do
    #       [...]
    #       process "make sure my dependencies have been loaded" do
    #         run_data_miner_on_parent_associations!
    #       end
    #       [...]
    #     end
    #   end
    #
    # @return nil
    def run_data_miner_on_parent_associations!
      reflect_on_all_associations(:belongs_to).reject do |assoc|
        assoc.options['polymorphic']
      end.map do |non_polymorphic_belongs_to_assoc|
        non_polymorphic_belongs_to_assoc.klass.run_data_miner!
      end
      nil
    end
    
    # Define a data miner script.
    #
    # @param [optional, Hash] options
    # @option options [TrueClass, FalseClass] :append (false) Add steps to existing data miner script instead of starting from scratch.
    #
    # @yield [] The block defining the steps.
    #
    # @see DataMiner::Script#import Creating an import step by calling DataMiner::Script#import from inside a data miner script
    # @see DataMiner::Script#process Creating a process step by calling DataMiner::Script#process from inside a data miner script
    # @see DataMiner::Script#sql Creating a sql step by calling DataMiner::Script#sql from inside a data miner script
    #
    # @example Creating steps
    #   class MyModel < ActiveRecord::Base
    #     data_miner do
    #       process [...]
    #       import [...]
    #       import [...yes, it's ok to have more than one import step...]
    #       sql [...]
    #       process [...]
    #       [...etc...]
    #     end
    #   end
    #
    # @example From the README
    #   class Country < ActiveRecord::Base
    #     self.primary_key = 'iso_3166_code'
    #     data_miner do
    #       import("OpenGeoCode.org's Country Codes to Country Names list",
    #              :url => 'http://opengeocode.org/download/countrynames.txt',
    #              :format => :delimited,
    #              :delimiter => '; ',
    #              :headers => false,
    #              :skip => 22) do
    #         key   :iso_3166_code, :field_number => 0
    #         store :iso_3166_alpha_3_code, :field_number => 1
    #         store :iso_3166_numeric_code, :field_number => 2
    #         store :name, :field_number => 5
    #       end
    #     end
    #   end
    #
    # @return [nil]
    def data_miner(options = {}, &blk)
      options = options.stringify_keys
      unless options['append']
        @data_miner_script = nil
      end
      data_miner_script.append_block blk
      nil
    end
  end
end
