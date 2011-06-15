require 'test_helper'

module ActiveRecord
  class ActiveRecord::Base
  end
end

class DeferredTest < MiniTest::Unit::TestCase


  class User < ActiveRecord::Base

    def self.find(id)
      all.detect { |record| record.id == id }
    end

    def self.all
      @all ||= [ User.new(:id => 1, :name => 'Squirrel'),
        User.new(:id => 2, :name => 'Raccoon'),
        User.new(:id => 3, :name => 'Bear') ]
    end

    attr_accessor :id, :name

    def initialize(attributes)
      self.id   = attributes[:id]
      self.name = attributes[:name]
    end

  end

  class DeferredMailer

    def delivery_welcome(message, attributes)
      "#{message} #{attributes['user'].join(',')}"
    end

  end

  describe 'Deferred' do
    before do
      @deferred = Convoy::ActionMailer::Deferred.new(
        'mailer_name'  => 'DeferredMailer',
        'method_id'    => 'welcome',
        'arguments'    => [ 'Hello!', { 'users' => User.all } ])
    end

    it 'is equal to another deferred object when all params are equal' do
      other = Convoy::ActionMailer::Deferred.new(
        'mailer_name'  => 'DeferredMailer',
        'method_id'    => 'welcome',
        'arguments'    => [ 'Hello!', { 'users' => User.all } ])

      assert_equal @deferred, other
    end

    describe 'valid?' do

      it 'is false when :mailer_name, :method_id or :arguments are missing' do
        @deferred.params.delete(:mailer_name)
        assert_equal false, @deferred.valid?
      end

      it 'is true when :mailer_name, :method_id, and :arguments are all present' do
        assert_equal true, @deferred.valid?
      end

      it 'populates errors' do
        assert_equal nil, @deferred.errors
        @deferred.valid?
        assert_equal [], @deferred.errors

        @deferred.params.delete(:mailer_name)
        @deferred.valid?
        assert_equal [ "mailer_name can't be nil" ], @deferred.errors
      end

    end

    describe 'to_json' do

      it 'converts ActiveRecord objects into an easily deserializable form' do
        encoded = '{"mailer_name":"DeferredMailer","method_id":"welcome","arguments":["Hello!",{"users":[{"class":"DeferredTest::User","id":1},{"class":"DeferredTest::User","id":2},{"class":"DeferredTest::User","id":3}]}]}'
        assert_equal encoded, @deferred.to_json
      end

    end

    describe 'from_json' do

      it 'deserializes correctly' do
        decoded = Convoy::ActionMailer::Deferred.from_json(@deferred.to_json)
        assert_equal 'DeferredMailer', decoded.mailer_name
        assert_equal 'welcome',     decoded.method_id
        assert_equal  [ 'Hello!', { 'users' => User.all } ], decoded.arguments
      end

    end

    describe 'RecordEncoder' do

      it "throws an exception when encoding records that can't be decoded" do
        record = User.new(:id => nil)
        exception = Convoy::ActionMailer::Deferred::RecordEncoder::RecordIdMissingError
        encoder   = Convoy::ActionMailer::Deferred::RecordEncoder

        assert_raises(exception) { encoder.encode({ :record => record }) }
      end

    end

  end

end


