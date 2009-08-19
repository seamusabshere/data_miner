def grab(keys)
  Array.wrap(keys).inject([]) { |memo, n| memo + ENV[n].to_s.split(/\s*,\s*/).flatten.compact } #lol
end

def classes
  grab(%w(CLASS CLASSES))
end

def numbers
  grab(%w(NUM NUMS NUMBER NUMBERS))
end

namespace :data_miner do
  task :setup_logger => :environment do
    DataMiner.logger = Logger.new(STDERR)
  end
  
  task :signature => :setup_logger do
    puts DataMiner.signature(:classes => classes, :numbers => numbers).join("\n")
  end
  
  task :report_on => :setup_logger do
    puts DataMiner.report_on(:affected => grab('AFFECTED'), :classes => classes, :numbers => numbers)
  end

  task :errors => :setup_logger do
    puts DataMiner.errors(:classes => classes, :numbers => numbers).map(&:full_message)
  end

  task :warnings => :setup_logger do
    puts DataMiner.warnings(:classes => classes, :numbers => numbers).map(&:full_message)
  end
  
  task :classes => :setup_logger do
    puts DataMiner.classes.join("\n")
  end

  task :mine_data => :setup_logger do
    DataMiner.mine_data!(:classes => classes, :numbers => numbers)
  end
end
