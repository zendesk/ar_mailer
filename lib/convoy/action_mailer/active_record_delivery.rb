require 'active_support/core_ext/class/attribute'

module Convoy
  module ActionMailer
    module ActiveRecordDelivery

     def self.included(base)
       base.class_attribute :email_class
     end

     def perform_delivery_activerecord(mail)
       destinations = mail.destinations
       mail.ready_to_send

       destinations.each do |destination|
         email_class.create :mail => mail.encoded, :to => destination, :from => mail.from.first
       end
     end

    end
  end
end
