module Convoy
  class Dispatcher
    attr_reader   :app           # The Delivery app
    attr_reader   :delay         # Seconds to delay between runs
    attr_reader   :log_header    # Logs the value of this header for successfully sent emails

    attr_accessor :once          # True if only one delivery attempt will be made per call to run
    attr_accessor :max_age       # Maximum age of emails in seconds before they are removed from the queue.
    attr_accessor :batch_size    # Email delivery attempts per run
    attr_accessor :smtp_settings # Configuration for :user, :domain, :password, :authentication
    attr_accessor :delivery_settings

    attr_accessor :queue         # A queue that provides emails. Should respond to cleanup and retrieve.

    def initialize(app, options = {})
      @app        = app
      @once       = options[:once]
      @log_header = options[:log_header]
      @batch_size = options[:batch_size]
      @delay      = options[:delay]   || 60
      @max_age    = options[:max_age] || 86400 * 7 # Cleanup

      @smtp_settings     = options[:smtp_settings]     || {}
      @delivery_settings = options[:delivery_settings] || {}
      @delivery_settings.merge!(:log_header => @log_header, :delay => @delay)
    end

    # Scans for emails and delivers them every delay seconds.  Only returns if
    # once is true.
    def run
      install_signal_handlers

      loop do
        deliveries = deliver
        break deliveries if @stop || @once
      end
    end

    def install_signal_handlers
      trap 'TERM' do do_exit end
      trap 'INT'  do do_exit end
    end

    def do_exit
      log 'caught signal, shutting down'
      exit
    end

    def log(message)
      Convoy.log(message)
    end

    module Extendable

      def deliver
        emails.map do |email|
          delivery = app.new(server, delivery_settings)
          delivery.deliver(email)
          delivery
        end
      end

      def server
        @server ||= SMTP::Server.new(smtp_settings)
      end

      def emails
        options = {
          :before => Time.now.to_i - 300,
          :limit  => batch_size
        }
        emails = queue.retrieve(options)

        log "found #{emails.length} emails to send"
        emails
      end

    end
    include Extendable

  end
end
