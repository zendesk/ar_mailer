require 'test_helper'
require 'timecop'

class DispatcherTest < MiniTest::Unit::TestCase

  class TestDelivery

    attr_reader :messages

    def initialize(server, settings)
      @server   = server
      @settings = settings
      @messages = []
    end

    def deliver(message)
      @messages << message
    end

  end

  class MailQueue < Array

    def retrieve(options)
      [ first ]
    end

  end

  describe 'Dispatcher' do
    before do
      @dispatcher = Convoy::Dispatcher.new(TestDelivery, :once => true)
      @dispatcher.queue = MailQueue.new
    end

    describe 'run' do

      it 'delivers messages' do
        @dispatcher.queue.push 'Hello'
        deliveries = @dispatcher.run
        delivery   = deliveries.first

        assert_equal TestDelivery, delivery.class
        assert_equal [ 'Hello' ],  delivery.messages
      end

    end

  end

end
