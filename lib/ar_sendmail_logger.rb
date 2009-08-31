require 'logger'

class ARSendmailLogger < ::Logger

  def initialize(path)
    FileUtils.mkdir_p(File.dirname(path))
    super(path)
  end

  def format_message(severity, timestamp, progname, message)
    "#{message}\n"
  end

end
