class DataMiner
  class UnitConverter
    def self.load(type)
      require "data_miner/unit_converter/#{type}"
      const_get(type.to_s.camelize).new
    end

    def convert(value, from, to)
      if from.blank? or to.blank?
        raise ::RuntimeError, "[data_miner] Missing units (from=#{final_from_units.inspect}, to=#{final_to_units.inspect}"
      end
    end
  end
end
