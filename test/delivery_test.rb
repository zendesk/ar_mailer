require 'test_helper'

class DeliveryTest < MiniTest::Unit::TestCase

  class Email

    attr_accessor :id, :to, :from, :mail
    attr_reader   :status

    def to_message
      return to, from, mail
    end

    def sent!
      @status = :sent
    end

    def attempted!
      @status = :attempted
    end

    def canceled!
      @status = :canceled
    end

  end

  describe 'Delivery' do
    before do
      @session  = MiniTest::Mock.new
      @session.expect(:reset, nil)

      @server   = MiniTest::Mock.new
      @server.expect(:session, @session)

      @delivery = Convoy::Delivery.new(@server)
      @email    = Email.new
    end

    describe 'success' do
      before do
        @server.expect(:receive, [ :success, '250 OK' ], [@email.to_message])
      end

      it 'marks the message as sent' do
        @delivery.deliver(@email)
        assert_equal :sent, @email.status
      end

    end

    describe 'busy' do
      before do
        @exception = Exception.new('450 Error').tap { |exception| exception.set_backtrace('1: Failed.') }
        @server.expect(:receive, [ :busy, @exception ], [@email.to_message])
      end

      it 'marks the message as attempted' do
        @delivery.deliver(@email)
        assert_equal :attempted, @email.status
      end

      it 'delays further send attempts' do
        assert_equal false, @delivery.delayed?
        @delivery.deliver(@email)

        assert_equal true, @delivery.delayed?
      end

    end

    describe 'temporary failure' do
      before do
        @exception = Exception.new('450 Error').tap { |exception| exception.set_backtrace('1: Failed.') }
        @server.expect(:receive, [ :temporary_failure, @exception ], [@email.to_message])
      end

      it 'marks the message as attempted' do
        @delivery.deliver(@email)
        assert_equal :attempted, @email.status
      end

      it 'resets the session' do
        @delivery.deliver(@email)
        assert @session.verify
      end

    end

    describe 'permenant failure' do
      before do
        @exception = Exception.new('550 Error').tap { |exception| exception.set_backtrace('1: Failed.') }
        @server.expect(:receive, [ :permenant_failure, @exception ], [@email.to_message])
      end

      it 'cancels the message' do
        @delivery.deliver(@email)
        assert_equal :canceled, @email.status
      end

      it 'resets the session' do
        @delivery.deliver(@email)
        assert @session.verify
      end

    end

  end
end
