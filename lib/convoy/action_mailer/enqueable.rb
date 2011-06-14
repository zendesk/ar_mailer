require 'active_support/core_ext/class/attribute'

module Convoy
  module ActionMailer
    module Enqueable

      def self.extended(base)
        base.class_attribute :queue
      end

      def method_missing(method_symbol, *parameters) #:nodoc:
        if match = matches_dynamic_method?(method_symbol)
          if queue && match[1] == 'deliver'
            enqueue(match[2], parameters)
          else
            super
          end
        end
      end

      def enqueue(method_id, arguments)
        deferred = Deferred.new(:mailer_name => name, :method_id => method_id, :arguments => arguments)
        queue.enqueue(:deferred => deferred)
        deferred
      end

    end
  end
end
