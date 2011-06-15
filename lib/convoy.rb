module Convoy
  autoload :ActionMailer, 'convoy/action_mailer'
  autoload :Delivery,     'convoy/delivery'
  autoload :Dispatcher,   'convoy/dispatcher'
  autoload :Extensions,   'convoy/extensions'
  autoload :Queue,        'convoy/queue'

  module SMTP
    autoload :Server, 'convoy/smtp/server'
  end

  def self.log(message)
    $stdout.puts(message)
  end

  def self.warn(message)
    $stderr.puts(message)
  end

end
