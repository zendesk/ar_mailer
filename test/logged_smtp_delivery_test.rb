require 'test_helper'
require 'tmail'
require 'logger'
require 'test/resources/action_mailer'

class LoggedSMTPDeliveryTest < MiniTest::Unit::TestCase

  class FakeFileLogger

    def messages
      @messages ||= []
    end

    def log(message)
      messages << message
    end

    def reset
      messages.clear
    end

  end

  class ApplicationMailer
    include Convoy::ActionMailer::LoggedSMTPDelivery

    self.mail_file_logger  = FakeFileLogger.new

    def deliver_welcome
      @mail = TMail::Mail.new.tap do |mail|
        mail.to   = 'you@example.com'
        mail.from = 'me@example.com'
        mail.body = 'hello'
      end
      perform_delivery_logged_smtp(@mail)
    end

    def server_settings
      {}
    end

    def logger
      Logger.new(StringIO.new)
    end

  end

  describe 'deliverying via actionmailer' do
    before do
      Net::SMTP.reset
      FakeActionMailer::Base.reset
      ApplicationMailer.mail_file_logger.reset
    end

    it 'logs the mail to a file when the mail file logger is available' do
      ApplicationMailer.new.deliver_welcome

      assert_equal "From: me@example.com\r\nTo: you@example.com\r\n\r\nhello", ApplicationMailer.mail_file_logger.messages.last
      ApplicationMailer.mail_file_logger.messages.clear
      original_logger = ApplicationMailer.mail_file_logger
      ApplicationMailer.mail_file_logger = nil
      assert ApplicationMailer.new.deliver_welcome
      ApplicationMailer.mail_file_logger = original_logger
    end

    it 'delivers the mail' do
      ApplicationMailer.new.deliver_welcome
      delivery = ["From: me@example.com\r\nTo: you@example.com\r\n\r\nhello", "me@example.com", ["you@example.com"]]

      assert_equal delivery, Net::SMTP.deliveries.last
    end

  end

  describe 'SMTP Delivery' do
    before do
      @settings = {}
      @mail     = TMail::Mail.new.tap do |mail|
        mail.message_id = '<12345@example.com>'
      end
      @delivery = Convoy::ActionMailer::LoggedSMTPDelivery::SMTPDelivery.new(@mail, @settings)
      @log      = StringIO.new
      @delivery.logger = Logger.new(@log)
      @delivery.logger.formatter = lambda { |severity, datetime, progname, msg| msg }
    end

    it 'has the sender via the first from address' do
      @mail.from = [ 'a@example.com', 'b@example.com' ]
      assert_equal 'a@example.com', @delivery.sender
    end

    it 'has a list of destination addresses' do
      @mail.to  = 'to@example.com'
      @mail.cc  = 'cc@example.com'
      @mail.bcc = 'bcc@example.com'

      assert_equal [ 'to@example.com', 'cc@example.com','bcc@example.com' ], @delivery.destinations
    end

    it 'has an smtp connection' do
      @delivery.settings[:address] = 'example.com'
      @delivery.settings[:port]    = 26

      smtp = @delivery.smtp
      assert_equal 26,            smtp.port
      assert_equal 'example.com', smtp.address
      assert_equal true,          smtp.starttls_auto?

      @delivery.settings[:tls]    = false
      assert_equal false,         @delivery.smtp.starttls_auto?
    end

    it 'logs with the mail message id' do
      @delivery.log 'hello'

      assert_equal '<12345@example.com>: hello', @log.string
    end

    it 'logs headers when the log header is provided' do
      @delivery.log_headers
      assert_equal '', @log.string

      @delivery.settings[:log_header] = 'X-Delivery-Context'
      @delivery.mail['X-Delivery-Context'] = 'hello-33'
      @delivery.log_headers

      assert_equal '<12345@example.com>: X-Delivery-Context [hello-33]', @log.string
    end

    it 'sends the mail' do
      @mail.from = 'me@example.com'
      @mail.to   = 'you@example.com'
      @mail.cc   = 'cc@example.com'
      @mail.body = 'hello'
      message = [
        "From: me@example.com\r\nTo: you@example.com\r\nCc: cc@example.com\r\nMessage-Id: <12345@example.com>\r\n\r\nhello",
        "me@example.com",
        ["you@example.com", "cc@example.com"]
      ]
      @delivery.perform

      assert_equal message, Net::SMTP.deliveries.last
    end

    it 'does not include BCC addresses in the message' do
      assert_equal false, @delivery.message.include?('bcc@example.com')
    end

  end

end
