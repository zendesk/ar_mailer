module Convoy
  autoload :ActionMailer, 'convoy/action_mailer'
  autoload :Delivery,     'convoy/delivery'
  autoload :Dispatcher,   'convoy/dispatcher'
  autoload :Extensions,   'convoy/extensions'

  module SMTP
    autoload :Server, 'convoy/smtp/server'
  end

  def self.log(message)
    $stdout.puts(log_format(message))
  end

  def self.warn(message)
    $stderr.puts(log_format(message))
  end

  def self.log_format(message)
    "ar_sendmail #{Time.now}: #{message}"
  end

end
