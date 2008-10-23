require 'logger'

class ArSendmailLogger < ::Logger

  def format_message(severity, timestamp, progname, message)
    "#{message}\n"
  end

end
