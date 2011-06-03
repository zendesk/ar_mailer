require 'test/unit'
require 'rubygems'
require 'minitest/autorun'
require 'ruby-debug'

$LOAD_PATH.unshift(File.expand_path('lib'))
require 'convoy'

module Sleepy

  attr_accessor :slept

  def sleep(secs)
    @slept ||= []
    @slept << secs
  end

end
