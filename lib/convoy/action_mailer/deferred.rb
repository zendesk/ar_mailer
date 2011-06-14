require 'active_support/core_ext/hash'
require 'active_support'

module Convoy
  module ActionMailer
    class Deferred

      def self.from_json(params)
        from_hash(ActiveSupport::JSON.decode(params))
      end

      def self.from_hash(params)
        decoded = encoder.decode(params)

        new(decoded)
      end

      def self.encoder
        RecordEncoder
      end

      def initialize(params)
        @params = params
        @params.symbolize_keys!
      end

      # ActionMailer does some bizzare stuff with #new.
      def mailer
        @mailer ||= begin
                      mailer = mailer_class.allocate
                      mailer.send(:initialize, method_id, *arguments)
                      mailer
                    end
      end

      def mailer_class
        mailer_name.constantize
      end

      def mailer_name
        params[:mailer_name]
      end

      def method_id
        params[:method_id]
      end

      def arguments
        params[:arguments]
      end

      def to_json(options = {})
        ActiveSupport::JSON.encode(encoded)
      end

      def encoded
        self.class.encoder.encode(params)
      end

      def ==(other)
        other.respond_to?(:params) &&
          other.params == params
      end

      protected

      attr_reader :params

      # Prepare ActiveRecord objects for safe serialization.
      #
      # user = User.first
      # => #<User id: 1, account_id: 1, name: 'Buddhy'>
      # RecordEncoder.encode(user)
      # => { :class => 'User', :id => 1 }
      # RecordEncoder.decode(user)
      # => #<User id: 1, account_id: 1, name: 'Buddhy'>
      #
      module RecordEncoder
        class RecordIdMissingError < ArgumentError
          def initialize(record)
            @record = record
          end

          def message
            "ActiveRecords must have an id to be serialized: (#{@record.inspect})"
          end
        end
        CLASS = 'class'.freeze
        ID    = 'id'.freeze

        extend self

        def encode(params)
          encoded = params.map do |argument|
            case argument
            when ActiveRecord::Base
              encode_active_record(argument)
            when Array, Hash
              encode(argument)
            when NilClass, TrueClass, FalseClass, Numeric, String, Symbol
              argument
            else
              raise ArgumentError.new("Cannot encode #{argument} (#{argument.class})")
            end
          end

          params.is_a?(Hash) ? Hash[encoded] : encoded
        end

        def decode(params)
          decoded = params.map do |argument|
            case argument
            when Hash
              active_record?(argument) ? decode_active_record(argument) : decode(argument)
            when Array
              decode(argument)
            else
              argument
            end
          end

          params.is_a?(Hash) ? Hash[decoded] : decoded
        end

        protected

        def decode_active_record(params)
          params[CLASS].constantize.find(params[ID])
        end

        def active_record?(params)
          params[CLASS] && params[ID]
        end

        def encode_active_record(record)
          raise RecordIdMissingError.new(record) if record.id.to_s.empty?

          { CLASS => record.class.name, ID => record.id }
        end

      end

    end
  end
end
