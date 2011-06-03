module Net # :nodoc:
  class SMTP # :nodoc:

    unless instance_methods.include? 'reset' then
      ##
      # Resets the SMTP connection.

      def reset
        getok 'RSET'
      end
    end

  end
end
