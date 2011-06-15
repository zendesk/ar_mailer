require 'test_helper'
require 'tmpdir'
require 'fileutils'

class MaildirTest < MiniTest::Unit::TestCase

  class TestMail

    attr_accessor :message_id, :encoded

  end

  describe 'Maildir' do
    before do
      @path = Dir.mktmpdir
      [ 'tmp', 'new', 'cur' ].each do |name|
        Dir.mkdir(File.join(@path, name))
      end

      @maildir = Convoy::Queue::Maildir.new(@path)
      @mail    = TestMail.new.tap do |mail|
        mail.message_id = "<12345@example.com>"
        mail.encoded    = "Hello!\nGoodbye!"
      end
    end

    after do
      FileUtils.remove_entry_secure(@path)
    end

    describe 'push' do

      it 'writes the raw email to the "new" mail directory' do
        @maildir.push(@mail)
        new_mail_path = "#{@maildir.root_path}/new/e934e800f8e9a927a83f4d3ba791b73c.eml"
        assert File.exist?(new_mail_path)
        assert_equal "Hello!\nGoodbye!", File.read(new_mail_path)
      end

    end

    it 'calculates the new path for mail' do
      maildir = Convoy::Queue::Maildir.new('mails')
      new_mail_path = "mails/new/e934e800f8e9a927a83f4d3ba791b73c.eml"
      assert_equal new_mail_path, maildir.new_mail_path(@mail)
    end

  end
end
