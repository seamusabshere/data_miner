#!/usr/bin/env rake
require "bundler/gem_tasks"

require 'rake'
require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :test_separately do
  Dir[File.expand_path('../test/**/test_*.rb', __FILE__)].each do |path|
    sleep 0.5
    system "rake test TEST=#{path}"
  end
end

task :default => :test_separately

require 'yard'
YARD::Rake::YardocTask.new do |y|
  y.options << '--no-private'
end

gemspec = eval(File.read(Dir["*.gemspec"].first))

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end

desc "Build gem locally"
task :build => :gemspec do
  system "gem build #{gemspec.name}.gemspec"
  FileUtils.mkdir_p "pkg"
  FileUtils.mv "#{gemspec.name}-#{gemspec.version}.gem", "pkg"
end

desc "Install gem locally"
task :install => :build do
  system "gem install pkg/#{gemspec.name}-#{gemspec.version}"
end

desc "Clean automatically generated files"
task :clean do
  FileUtils.rm_rf "pkg"
end
