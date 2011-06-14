require 'test_helper'
require 'test/resources/action_mailer'
require 'mocha'

module ActionMailer
end
class ActionMailer::ARSendmail < Convoy::Dispatcher
  include Convoy::Extensions::Delay
  include Convoy::Extensions::ServerSession
  include Convoy::Extensions::Cleanup
  include Sleepy

  def queue
    Email
  end

end

class Convoy::SMTP::Server
  include Sleepy

end

class Convoy::Delivery
  include Sleepy

end

class TestARSendmail < MiniTest::Unit::TestCase

  def setup
    FakeActionMailer::Base.reset
    Email.reset
    Net::SMTP.reset

    @sm = ActionMailer::ARSendmail.new(Convoy::Delivery)

    Net::SMTP.clear_on_start

    @include_c_e = ! $".grep(/config\/environment.rb/).empty?
    $" << 'config/environment.rb' unless @include_c_e
  end

  def teardown
    $".delete 'config/environment.rb' unless @include_c_e
  end

  def strip_log_prefix(line)
    line.gsub(/ar_sendmail .+ \d{4}: /,'')
  end

  def test_class_new
    @sm = ActionMailer::ARSendmail.new(Convoy::Delivery)

    assert_equal 60, @sm.delay
    assert_equal nil, @sm.once
    assert_equal nil, @sm.batch_size

    @sm = ActionMailer::ARSendmail.new Convoy::Delivery, :delay => 75, :verbose => true,
                                       :once => true, :batch_size => 1000

    assert_equal 75, @sm.delay
    assert_equal true, @sm.once
    assert_equal 1000, @sm.batch_size
  end

  def test_cleanup
    e1 = Email.create :mail => 'body', :to => 'to', :from => 'from'
    e1.created_on = Time.now
    e2 = Email.create :mail => 'body', :to => 'to', :from => 'from'
    e3 = Email.create :mail => 'body', :to => 'to', :from => 'from'
    e3.last_send_attempt = Time.now

    out, err = capture_io do
      @sm.cleanup
    end

    assert_equal '', err
    assert_equal "expired 1 emails from the queue\n", strip_log_prefix(out)
    assert_equal 2, Email.records.length

    assert_equal [e1, e2], Email.records
  end

  def test_cleanup_disabled
    e1 = Email.create :mail => 'body', :to => 'to', :from => 'from'
    e1.created_on = Time.now
    e2 = Email.create :mail => 'body', :to => 'to', :from => 'from'

    @sm.max_age = 0

    out, err = capture_io do
      @sm.cleanup
    end

    assert_equal '', out
    assert_equal 2, Email.records.length
  end

  def test_deliver
    email = Email.create :mail => 'body', :to => 'to', :from => 'from'

    out, err = capture_io do
      @sm.deliver
    end

    assert_equal 1, Net::SMTP.deliveries.length
    assert_equal ['body', 'from', 'to'], Net::SMTP.deliveries.first
    assert_equal 0, Email.records.length
    assert_equal 0, Net::SMTP.reset_called, 'Reset connection on SyntaxError'

    assert_equal '', err
    assert_match "sent email 00000000001 from from to to: \"queued\"\n", out
  end

  def test_log_header_setting
    email = Email.create :mail => "Mailer: JunkMail 1.0\r\nX-Track: 7890\r\n\r\nbody", :to => 'to', :from => 'from'
    @sm.delivery_settings[:log_header] = 'X-Track'
    out, err = capture_io do
      @sm.deliver
    end

    assert_equal 1, Net::SMTP.deliveries.length
    assert_equal 0, Email.records.length
    assert_equal 0, Net::SMTP.reset_called, 'Reset connection on SyntaxError'

    assert_equal '', err
    assert_match "sent email 00000000001 [7890] from from to to: \"queued\"\n", strip_log_prefix(out)
  end

  def test_deliver_not_called_when_no_emails
    sm = ActionMailer::ARSendmail.new(Convoy::Delivery, :once => true)
    Convoy::Delivery.any_instance.expects(:deliver).never
    sm.run
  end

  def test_deliver_auth_error
    Net::SMTP.on_start do
      e = Net::SMTPAuthenticationError.new 'try again'
      e.set_backtrace %w[one two three]
      raise e
    end

    now = Time.now.to_i

    email = Email.create :mail => 'body', :to => 'to', :from => 'from'

    out, err = capture_io do
      assert_raises(Net::SMTPAuthenticationError) do
        @sm.deliver
      end
    end

    assert_equal 0, Net::SMTP.deliveries.length
    assert_equal 1, Email.records.length
    assert_equal 0, Email.records.first.last_send_attempt
    assert_equal 0, Net::SMTP.reset_called
    assert_equal 2, @sm.server.failed_auth_count
    assert_equal [60], @sm.server.slept

    assert_match "authentication error, retrying: try again\n", strip_log_prefix(err)
  end

  def test_deliver_auth_error_recover
    email = Email.create :mail => 'body', :to => 'to', :from => 'from'
    @sm.server.failed_auth_count = 1

    out, err = capture_io do @sm.deliver end

    assert_equal 0, @sm.server.failed_auth_count
    assert_equal 1, Net::SMTP.deliveries.length
  end

  def test_deliver_auth_error_twice
    Net::SMTP.on_start do
      e = Net::SMTPAuthenticationError.new 'try again'
      e.set_backtrace %w[one two three]
      raise e
    end

    @sm.server.failed_auth_count = 1

    out, err = capture_io do
      assert_raises Net::SMTPAuthenticationError do
        @sm.deliver
      end
    end

    assert_equal 2, @sm.server.failed_auth_count
    assert_equal "authentication error, giving up: try again\n", strip_log_prefix(err)
  end

  def test_deliver_4xx_error
    Net::SMTP.on_send_message do
      e = Net::SMTPSyntaxError.new 'try again'
      e.set_backtrace %w[one two three]
      raise e
    end

    now = Time.now.to_i

    email = Email.create :mail => 'body', :to => 'to', :from => 'from'

    out, err = capture_io do
      @sm.deliver
    end

    assert_equal 0, Net::SMTP.deliveries.length
    assert_equal 1, Email.records.length
    assert_operator now, :<=, Email.records.first.last_send_attempt
    assert_equal 1, Net::SMTP.reset_called, 'Reset connection on SyntaxError'

    assert_equal "error sending email 1: \"try again\"(Net::SMTPSyntaxError):\n\tone\n\ttwo\n\tthree\n", strip_log_prefix(err)
  end

  def test_deliver_5xx_error
    Net::SMTP.on_send_message do
      e = Net::SMTPFatalError.new 'unknown recipient'
      e.set_backtrace %w[one two three]
      raise e
    end

    now = Time.now.to_i

    email = Email.create :mail => 'body', :to => 'to', :from => 'from'

    out, err = capture_io do
      @sm.deliver
    end

    assert_equal 0, Net::SMTP.deliveries.length
    assert_equal 0, Email.records.length
    assert_equal 1, Net::SMTP.reset_called, 'Reset connection on SyntaxError'

    assert_equal "5xx error sending email 1, removing from queue: \"unknown recipient\"(Net::SMTPFatalError):\n\tone\n\ttwo\n\tthree\n", strip_log_prefix(err)
  end

  def test_deliver_errno_epipe
    Net::SMTP.on_send_message do
      raise Errno::EPIPE
    end

    now = Time.now.to_i

    email = Email.create :mail => 'body', :to => 'to', :from => 'from'

    out, err = capture_io do
      @sm.deliver
    end

    assert_equal 0, Net::SMTP.deliveries.length
    assert_equal 1, Email.records.length
    assert_operator now, :>=, Email.records.first.last_send_attempt
    assert_equal 0, Net::SMTP.reset_called, 'Reset connection on SyntaxError'

    assert_equal "Ignoring SMTP connection error: #<Errno::EPIPE: Broken pipe>\n", err
  end

  def test_deliver_server_busy
    Net::SMTP.on_send_message do
      e = Net::SMTPServerBusy.new 'try again'
      e.set_backtrace %w[one two three]
      raise e
    end

    now = Time.now.to_i

    email = Email.create :mail => 'body', :to => 'to', :from => 'from'

    result = nil
    out, err = capture_io do
      result = @sm.deliver
    end

    assert_equal 0, Net::SMTP.deliveries.length
    assert_equal 1, Email.records.length
    assert_operator now, :>=, Email.records.first.last_send_attempt
    assert_equal 0, Net::SMTP.reset_called, 'Reset connection on SyntaxError'
    assert_equal [60], result.last.slept

    assert_equal "server too busy, sleeping 60 seconds\n", strip_log_prefix(err)
  end

  def test_deliver_syntax_error
    Net::SMTP.on_send_message do
      Net::SMTP.on_send_message # clear
      e = Net::SMTPSyntaxError.new 'blah blah blah'
      e.set_backtrace %w[one two three]
      raise e
    end

    now = Time.now.to_i

    email1 = Email.create :mail => 'body', :to => 'to', :from => 'from'
    email2 = Email.create :mail => 'body', :to => 'to', :from => 'from'

    out, err = capture_io do
      @sm.deliver
    end

    assert_equal 1, Net::SMTP.deliveries.length, 'delivery count'
    assert_equal 1, Email.records.length
    assert_equal 1, Net::SMTP.reset_called, 'Reset connection on SyntaxError'
    assert_operator now, :<=, Email.records.first.last_send_attempt

    assert_equal "error sending email 1: \"blah blah blah\"(Net::SMTPSyntaxError):\n\tone\n\ttwo\n\tthree\n", strip_log_prefix(err)
    assert_match "sent email 00000000002 from from to to: \"queued\"\n", out
  end

  def test_deliver_timeout
    Net::SMTP.on_send_message do
      e = Timeout::Error.new 'timed out'
      e.set_backtrace %w[one two three]
      raise e
    end

    now = Time.now.to_i

    email = Email.create :mail => 'body', :to => 'to', :from => 'from'

    out, err = capture_io do
      @sm.deliver
    end

    assert_equal 0, Net::SMTP.deliveries.length
    assert_equal 1, Email.records.length
    assert_operator now, :>=, Email.records.first.last_send_attempt
    assert_equal 1, Net::SMTP.reset_called, 'Reset connection on Timeout'

    assert_equal "error sending email 1: \"timed out\"(Timeout::Error):\n\tone\n\ttwo\n\tthree\n", strip_log_prefix(err)
  end

  def test_do_exit
    out, err = capture_io do
      assert_raises SystemExit do
        @sm.do_exit
      end
    end

    assert_equal '', err
    assert_equal "caught signal, shutting down\n", strip_log_prefix(out)
  end

  def test_log
    out, err = capture_io do
      @sm.log 'hi'
    end

    assert_equal "hi\n",  strip_log_prefix(out)
  end

  def test_find_emails
    email_data = [
      { :mail => 'body0', :to => 'recip@h1.example.com', :from => nobody },
      { :mail => 'body1', :to => 'recip@h1.example.com', :from => nobody },
      { :mail => 'body2', :to => 'recip@h2.example.com', :from => nobody },
    ]

    emails = email_data.map do |email_data| Email.create email_data end

    tried = Email.create :mail => 'body3', :to => 'recip@h3.example.com',
                         :from => nobody

    tried.last_send_attempt = Time.now.to_i - 258

    found_emails = []

    out, err = capture_io do
      found_emails = @sm.send(:emails)
    end

    assert_equal emails, found_emails

    assert_equal '', err
    assert_equal "found 3 emails to send\n", strip_log_prefix(out)
  end

  def nobody
    'nobody@example.com'
  end

end
