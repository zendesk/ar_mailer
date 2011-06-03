require 'test_helper'
require 'resources/action_mailer'

class SMTPServerdescribe < MiniTest::Unit::TestCase

  describe 'SMTP Server' do
    before do
      @server = Convoy::SMTP::Server.new({})
    end

    after do
      Net::SMTP.reset
    end

    describe 'connect' do
      after do
        Net::SMTP.on_start {}
      end

      it 'creates a session' do
        assert_equal nil, @server.session
        @server.connect { assert @server.session }
        assert_equal nil, @server.session
      end

      it 'retries authentication failures' do
        Net::SMTP.on_start do
          e = Net::SMTPAuthenticationError.new 'try again'
          e.set_backtrace %w[one two three]
          raise e
        end
        @server.extend(Sleepy)
        assert_raises(Net::SMTPAuthenticationError) { @server.connect {} }

        assert_equal 2, @server.max_auth_failures
        assert_equal 2, @server.failed_auth_count
        assert_equal [60], @server.slept
      end

    end

    describe 'receive' do

      it 'sends the message to the server' do
        @server.connect do
          status, response = @server.receive([ 'to', 'from', 'email' ])
          assert_equal 'queued', response
          assert_equal :success,  status
          assert_equal [ 'to', 'from', 'email' ], Net::SMTP.deliveries.last
        end
      end

      it 'responds with permenant failure when encountering SMTP Fatal errors' do
        Net::SMTP.on_send_message do
          e = Net::SMTPFatalError.new 'unknown recipient'
          e.set_backtrace %w[one two three]
          raise e
        end

        @server.connect do
          status, response = @server.receive([ 'to', 'from', 'email' ])
          assert_equal :permenant_failure,  status
          assert_equal Net::SMTPFatalError, response.class
        end
      end

      it 'responds with busy failure when encountering SMTP Server Busy errors' do
        Net::SMTP.on_send_message do
          e = Net::SMTPServerBusy.new 'unknown recipient'
          e.set_backtrace %w[one two three]
          raise e
        end

        @server.connect do
          status, response = @server.receive([ 'to', 'from', 'email' ])
          assert_equal :busy,  status
          assert_equal Net::SMTPServerBusy, response.class
        end
      end

      it 'responds with temporary failure when encountering SMTP Unknown errors' do
        Net::SMTP.on_send_message do
          e = Net::SMTPUnknownError.new 'unknown recipient'
          e.set_backtrace %w[one two three]
          raise e
        end

        @server.connect do
          status, response = @server.receive([ 'to', 'from', 'email' ])
          assert_equal :temporary_failure,  status
          assert_equal Net::SMTPUnknownError, response.class
        end
      end

      it 'responds with temporary failure when encountering SMTP Syntax errors' do
        Net::SMTP.on_send_message do
          e = Net::SMTPSyntaxError.new 'unknown recipient'
          e.set_backtrace %w[one two three]
          raise e
        end

        @server.connect do
          status, response = @server.receive([ 'to', 'from', 'email' ])
          assert_equal :temporary_failure,  status
          assert_equal Net::SMTPSyntaxError, response.class
        end
      end

      it 'responds with temporary fialure when encountering Timeout errors' do
        Net::SMTP.on_send_message do
          e = TimeoutError.new
          e.set_backtrace %w[one two three]
          raise e
        end

        @server.connect do
          status, response = @server.receive([ 'to', 'from', 'email' ])
          assert_equal :temporary_failure, status
          assert_equal Timeout::Error, response.class
        end
      end

      it 'raises exceptions it cannot handle' do
        Net::SMTP.on_send_message do
          e = ArgumentError.new
          e.set_backtrace %w[one two three]
          raise e
        end

        @server.connect do
          assert_raises(ArgumentError) { @server.receive([ 'to', 'from', 'email' ]) }
        end
      end

    end

  end
end
