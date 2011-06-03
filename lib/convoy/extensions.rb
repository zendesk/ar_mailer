module Convoy
  module Extensions
    module Delay

      def deliver
        now = Time.now
        value = super
        sleep @delay if now + @delay > Time.now
        value
      end

    end

    module Sharding

      def deliver
        ActiveRecord::Base.on_all_shards do
          super
        end
      end

    end

    module ServerSession

      def deliver
        server.connect do
          super
        end
      end
    end

    module ExceptionHandling

      def deliver
        begin
          super
        rescue ActiveRecord::Transactions::TransactionError
        end
      end

    end

    module Cleanup

      def deliver
        cleanup
        super
      end

      # Removes emails that have lived in the queue for too long.  If max_age is
      # set to 0, no emails will be removed.
      def cleanup
        return if @max_age == 0
        expired_at = Time.now - @max_age
        emails     = queue.cleanup(:expired_at => expired_at)

        log "expired #{emails.length} emails from the queue"
      end

    end

  end
end
