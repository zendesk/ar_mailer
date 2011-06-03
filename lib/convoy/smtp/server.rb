require 'net/smtp'
require 'convoy/smtp/reset'

# Status codes: http://www.ietf.org/rfc/rfc1893.txt
module Convoy
  module SMTP
    class Server
      STATUS_EXCEPTIONS = {
        Net::SMTPFatalError   => :permenant_failure,
        Net::SMTPServerBusy   => :busy,
        Net::SMTPUnknownError => :temporary_failure,
        Net::SMTPSyntaxError  => :temporary_failure,
        Timeout::Error        => :temporary_failure
      }

      attr_reader   :settings
      attr_accessor :max_auth_failures # Maximum number of times authentication will be consecutively retried. (2)
      attr_accessor :delay             # Seconds to delay between retries. (60)
      attr_accessor :tls               # Enable connection TLS. (true)

      attr_accessor :failed_auth_count, :session

      def initialize(settings)
        settings[:user] ||= settings[:user_name]
        @settings = settings
        @tls      = settings[:tls] != false
        @delay    = settings[:delay] || 60
        @max_auth_failures = settings[:max_auth_failures] || 2

        self.failed_auth_count = 0
      end

      def connect
        smtp.start(*settings.values_at(:domain, :user, :password, :authentication)) do |session|
          begin
            self.session = session
            yield
          ensure
            self.session = nil
            self.failed_auth_count = 0
          end
        end

      rescue Net::SMTPAuthenticationError => e
        self.failed_auth_count += 1
        if failed_auth_count >= max_auth_failures
          warn "authentication error, giving up: #{e.message}"
          raise e
        else
          warn "authentication error, retrying: #{e.message}"
          sleep delay
          retry
        end
      rescue Net::SMTPServerBusy, SystemCallError, OpenSSL::SSL::SSLError => e
        warn "Ignoring SMTP connection error: #{e.inspect}"
      end

      def receive(message)
        response = session.send_message(*message)
        return :success, response

      rescue *STATUS_EXCEPTIONS.keys => exception
        status = STATUS_EXCEPTIONS[exception.class]
        return status, exception
      end

      protected

      def smtp
        smtp = Net::SMTP.new(settings[:address], settings[:port])
        smtp.enable_starttls_auto if tls
        smtp
      end

      def log(message)
        Convoy.log(message)
      end

    end

  end
end
