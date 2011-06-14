module Convoy
  module ActionMailer
    autoload :ActiveRecordDelivery, 'convoy/action_mailer/active_record_delivery'
    autoload :Deferred,             'convoy/action_mailer/deferred'
    autoload :Enqueable,            'convoy/action_mailer/enqueable'
  end
end
