require 'rubygems'                                                                                                                                                                   
require 'rake'
require 'rspec/core/rake_task'

RAKE_ROOT = File.dirname(__FILE__)
Dir[ File.join(RAKE_ROOT, 'lib', 'tasks', '*') ].each { |f| require f }

def activerecord_db_config
  File.expand_path(File.join(RAKE_ROOT, 'conf', 'activerecord','db_config.yml'))
end


task :default do
  system("rake -T")
end

task :specs => [:spec]

desc "Run all rspec tests"
RSpec::Core::RakeTask.new(:spec) do |t| 
  t.rspec_opts = ['--color']
  # ignores fixtures directory.
  t.pattern = 'spec/**/*_spec.rb'
end

task :specs_html => [:spec_html]

desc "Run all rspec tests with html output"
fpath = "#{ENV['RAZOR_RSPEC_WEBPATH']||'.'}/razor_tests.html"
RSpec::Core::RakeTask.new(:spec_html) do |t| 
  t.rspec_opts = ['--color', '--format h', "--out #{fpath}"]
  # ignores fixtures directory.
  t.pattern = 'spec/**/*_spec.rb'
end
