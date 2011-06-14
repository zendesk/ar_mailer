require 'test_helper'
require 'action_mailer'

class EnqueableTest < MiniTest::Unit::TestCase

  class EnqueableMailer < ActionMailer::Base
    extend Convoy::ActionMailer::Enqueable

    self.delivery_method = :test

    def welcome(user)
      recipients   'You'
      from         'Me'

      body "Email: Hello, #{user}"
    end

  end

  class Queue < Array
    alias enqueue push
  end

  describe 'Mailer with a queue' do
    before do
      @queue = Queue.new
      EnqueableMailer.queue = @queue
    end

    it 'enqueues messages instead of deliverying them' do
      deferred = EnqueableMailer.deliver_welcome('Buddhy')
      assert_equal EnqueableMailer, deferred.mailer_class
      assert_equal 'welcome',       deferred.method_id
      assert_equal [ 'Buddhy' ],    deferred.arguments

      deferred = Convoy::ActionMailer::Deferred.new(:mailer_name => 'EnqueableTest::EnqueableMailer', :method_id => 'welcome', :arguments => [ 'Buddhy' ] )
      assert_equal [ { :deferred => deferred } ], @queue
    end

  end

  describe 'Mailer without a queue' do
    before do
      EnqueableMailer.queue = nil
    end

    it 'delivers messages without attempting to enqueue' do
      mail = EnqueableMailer.deliver_welcome('Buddhy')
      assert_equal 'Email: Hello, Buddhy', mail.body
    end

  end

end
