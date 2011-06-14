require 'net/smtp'
require 'time'

class Net::SMTP

  @reset_called = 0

  @deliveries = []

  @send_message_block = nil

  @start_block = nil

  class << self

    attr_reader :deliveries
    attr_reader :send_message_block
    attr_accessor :reset_called

    # send :remove_method, :start
  end

  def self.on_send_message(&block)
    @send_message_block = block
  end

  def self.on_start(&block)
    if block_given?
      @start_block = block
    else
      @start_block
    end
  end

  def self.clear_on_start
    @start_block = nil
  end

  def self.reset
    deliveries.clear
    on_start
    on_send_message
    @reset_called = 0
  end

  def start(*args)
    self.class.on_start.call if self.class.on_start
    yield self
  end

  alias test_old_reset reset if instance_methods.include? 'reset'

  def reset
    self.class.reset_called += 1
  end

  alias test_old_send_message send_message

  def send_message(mail, to, from)
    return self.class.send_message_block.call(mail, to, from) unless
      self.class.send_message_block.nil?
    self.class.deliveries << [mail, to, from]
    return "queued"
  end

end

##
# Stub for ActionMailer::Base
module FakeActionMailer; end

class FakeActionMailer::Base
  include Convoy::ActionMailer::ActiveRecordDelivery

  @server_settings = {}

  class << self
    #cattr_accessor :email_class
    attr_accessor :delivery_method
  end

  def self.logger
    o = Object.new
    def o.info(arg) end
    return o
  end

  def self.method_missing(meth, *args)
    meth.to_s =~ /deliver_(.*)/
    super unless $1
    new($1, *args).deliver!
  end

  def self.reset
    server_settings.clear
    self.email_class = Email
  end

  def self.server_settings
    @server_settings
  end

  def initialize(meth = nil)
    send meth if meth
  end

  def deliver!
    perform_delivery_activerecord @mail
  end

end
##
# Stub for an ActiveRecord model

class Email

  START = Time.parse 'Thu Aug 10 2006 11:19:48'

  attr_accessor :from, :to, :mail, :last_send_attempt, :created_on, :id

  @records = []
  @id = 0

  class << self; attr_accessor :records, :id; end

  def self.create(record)
    record = new record[:from], record[:to], record[:mail],
                 record[:last_send_attempt]
    records << record
    return record
  end

  def self.destroy_all(conditions)
    timeout = conditions.last
    found = []

    records.each do |record|
      next if record.last_send_attempt == 0
      next if record.created_on == 0
      next unless record.created_on < timeout
      record.destroy
      found << record
    end

    found
  end

  def self.find(_, conditions = nil)
    return records if conditions.nil?
    now = Time.now.to_i - 300
    return records.select do |r|
      r.last_send_attempt < now
    end
  end

  def self.reset
    @id = 0
    records.clear
  end

  def initialize(from, to, mail, last_send_attempt = nil)
    @from = from
    @to = to
    @mail = mail
    @id = self.class.id += 1
    @created_on = START + @id
    @last_send_attempt = last_send_attempt || 0
  end

  def destroy
    self.class.records.delete self
    self.freeze
  end

  def ==(other)
    other.id == id
  end

  def save
  end

  def self.retrieve(options)
    before = options.delete(:before)
    options[:conditions] = ['last_send_attempt < ?', before.to_i ]

    find(:all, options)
  end

  def self.cleanup(options)
    timeout = options.delete(:expired_at)
    destroy_all([ 'last_send_attempt > 0 and created_on < ?', timeout ])
  end

  def sent!
    destroy
  end

  def canceled!
    destroy
  end

  def attempted!
    self.last_send_attempt = Time.now.to_i
    save rescue nil
  end

  def to_message
    [ mail, from, to ]
  end

end

Newsletter = Email

class String
  def classify
    self
  end

  def tableize
    self.downcase
  end

end
