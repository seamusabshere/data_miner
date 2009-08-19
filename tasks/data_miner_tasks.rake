def split_class_names
  ENV['CLASSES'].to_s.split(/\s*,\s*/).flatten.compact
end

namespace :data_miner do
  task :mine => :environment do
    DataMiner.mine :class_names => split_class_names
  end
end
