require 'active_support/core_ext/class/attribute'

module Convoy
  module ActionMailer
    module ActiveRecordDelivery

     def self.included(base)
       base.class_attribute :email_class
     end

     def perform_delivery_activerecord(mail)
       original_bcc = mail.bcc
       destinations = mail.destinations
       mail.bcc     = nil

       destinations.each do |destination|
         email_class.create :mail => mail.encoded, :to => destination, :from => mail.from.first
       end
     ensure
       mail.bcc = original_bcc
     end

    end
  end
end
