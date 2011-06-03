require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/rdoctask'

$:.unshift(File.expand_path(File.dirname(__FILE__) + '/lib'))


desc "Update ar_mailer.gemspec"
task :make_spec do
  File.open("ar_mailer.gemspec", "w") do |f|
    f.puts(ar_mailer_gemspec.to_ruby)
  end
end

desc "Build packages and install"
task :install => :package do
  sh %{sudo gem install --local --test pkg/ar_mailer-#{ActionMailer::ARSendmail::VERSION}}
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the ar_mailer gem.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end
