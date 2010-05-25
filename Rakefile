require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "data_miner"
    gem.summary = %Q{Mine remote data into your ActiveRecord models.}
    gem.description = %Q{Mine remote data into your ActiveRecord models. You can also perform associations and convert units.}
    gem.email = "seamus@abshere.net"
    gem.homepage = "http://github.com/seamusabshere/data_miner"
    gem.authors = ["Seamus Abshere", "Andy Rossmeissl"]
    gem.add_dependency 'remote_table', '>=0.2.26'
    gem.add_dependency 'escape', '>=0.0.4'
    gem.add_dependency 'activerecord', '>=2.3.4'
    gem.add_dependency 'activesupport', '>=2.3.4'
    gem.add_dependency 'andand', '>=1.3.1'
    gem.add_dependency 'conversions', '>=1.4.4'
    gem.add_dependency 'blockenspiel', '>=0.3.2'
    gem.add_dependency 'log4r', '>=1.1.7'
    gem.add_dependency 'errata', '>=0.2.1'
    gem.add_dependency 'taps', '>=0.3.5'
    ## sabshere 5/25/10 i was told not to do this
    # gem.add_development_dependency "loose_tight_dictionary", ">=0.0.5"
    ## sabshere 5/25/10 i don't think i need this
    # gem.require_path = "lib"
    # gem.files.include %w(lib/data_miner) unless gem.files.empty? # seems to fail once it's in the wild
    gem.rdoc_options << '--line-numbers' << '--inline-source'
    ## sabshere 5/25/10 obsolete
    # gem.rubyforge_project = "dataminer"
  end
  Jeweler::GemcutterTasks.new
  ## sabshere 5/25/10 obsolete
  # Jeweler::RubyforgeTasks.new do |rubyforge|
  #   rubyforge.doc_task = "rdoc"
  # end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end




task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "data_miner #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
