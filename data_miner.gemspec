# -*- encoding: utf-8 -*-
require File.expand_path("../lib/data_miner/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "data_miner"
  s.version     = DataMiner::VERSION
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
  s.add_runtime_dependency 'errata', '>=1.0.1'
  s.add_runtime_dependency 'active_record_inline_schema'
end
