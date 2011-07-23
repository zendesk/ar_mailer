require 'test_helper'
require 'tmail'

class ActiveRecordDeliveryTest < MiniTest::Unit::TestCase

  class FakeEmail

    def self.all
      @all ||= []
    end

    def self.find_by_to(address)
      all.detect { |email| email[:to] == address }
    end

    def self.create(params)
      all.push(params)
    end

  end

  class TestMailer
    include Convoy::ActionMailer::ActiveRecordDelivery

    self.email_class = FakeEmail
  end

  describe 'Active Record delivery' do
    before do
      FakeEmail.all.clear

      @mail      = TMail::Mail.new
      @mail.from = 'from@example.com'
      @mail.to   = 'to@example.com'
      @mail.cc   = 'cc@example.com'
      @mail.bcc  = 'bcc@example.com'
      @mail.subject = 'hello'

      @mailer = TestMailer.new
    end

    it 'has a configurable mail class' do
      assert_equal FakeEmail, TestMailer.email_class
    end

    it 'creates an email record for each destination' do
      @mailer.perform_delivery_activerecord(@mail)

      assert FakeEmail.find_by_to('to@example.com'),  'Could not find: to@example.com'
      assert FakeEmail.find_by_to('cc@example.com'),  'Could not find: cc@example.com'
      assert FakeEmail.find_by_to('bcc@example.com'), 'Could not find: bcc@example.com'
    end

    it 'does not render the BCC address in the delivered mail' do
      @mailer.perform_delivery_activerecord(@mail)
      assert 3, FakeEmail.all.size

      FakeEmail.all.each do |email|
        assert_equal false, email[:mail].include?('bcc@example.com'), "BCC is in #{email.inspect}"
      end
    end

    it 'retains the BCC after delivery' do
      assert_equal [ 'bcc@example.com' ], @mail.bcc
      @mailer.perform_delivery_activerecord(@mail)
      assert_equal [ 'bcc@example.com' ], @mail.bcc
    end

  end

end
