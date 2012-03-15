# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "data_miner/version"

Gem::Specification.new do |s|
  s.name        = "data_miner"
  s.version     = DataMiner::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Seamus Abshere", "Andy Rossmeissl", "Derek Kastner"]
  s.email       = ["seamus@abshere.net"]
  s.homepage    = "https://github.com/seamusabshere/data_miner"
  s.summary     = %{Mine remote data into your ActiveRecord models.}
  s.description = %q{Mine remote data into your ActiveRecord models. You can also convert units.}

  s.rubyforge_project = "data_miner"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_runtime_dependency 'remote_table', '>=1.2.2'
  s.add_runtime_dependency 'activerecord', '>=2.3.4'
  s.add_runtime_dependency 'activesupport', '>=2.3.4'
  s.add_runtime_dependency 'conversions', '>=1.4.4'
  s.add_runtime_dependency 'blockenspiel', '>=0.3.2'
  s.add_runtime_dependency 'errata', '>=1.0.1'
  s.add_runtime_dependency 'unicode_utils' # for case-insensitive dictionary lookup with utf-8 characters
  s.add_development_dependency 'mini_record-compat'
  s.add_development_dependency 'loose_tight_dictionary', ">=0.0.5"
  s.add_development_dependency 'test-unit'
  s.add_development_dependency 'shoulda'
  s.add_development_dependency 'mysql'
  s.add_development_dependency 'rake'
  # if RUBY_VERSION >= '1.9'
  #   s.add_development_dependency 'ruby-debug19'
  # else
  #   s.add_development_dependency 'ruby-debug'
  # end
end
