module Convoy
  class Delivery

    attr_reader :email, :server, :status, :response

    def initialize(server, settings = {})
      @server     = server
      @settings   = settings
      @log_header = settings[:log_header]
      @delay      = settings[:delay].to_i
    end

    def deliver(email)
      @email = email
      @status, @response = server.receive(email.to_message)
      send(@status, @response)
    end

    def delayed?
      @delayed == true
    end

    protected

    def success(response)
      log "sent email %011d %sfrom %s to %s: %p" %
      [email.id, header_log, email.from, email.to, response]

      email.sent!
    end

    def busy(error)
      warn "server too busy, sleeping #{@delay} seconds"
      email.attempted!
      delay
    end

    def temporary_failure(error)
      warn "error sending email %d: %p(%s):\n\t%s" %
      [email.id, error.message, error.class, error.backtrace.join("\n\t")]

      email.attempted!
      session.reset
    end

    def permenant_failure(error)
      warn "5xx error sending email %d, removing from queue: %p(%s):\n\t%s" %
      [email.id, error.message, error.class, error.backtrace.join("\n\t")]

      email.canceled!
      session.reset
    end

    protected

    def session
      server.session
    end

    def delay
      @delayed = true
      sleep(@delay)
    end

    def log(message)
      Convoy.log(message)
    end

    def header_log
      if @log_header && email.mail =~ /#{@log_header}: (.+)/
        "[#{$1.chomp}] "
      else
        ''
      end
    end

  end
end
