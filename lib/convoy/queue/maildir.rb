module Convoy
  module Queue
    class Maildir

      attr_reader :root_path

      def initialize(root_path)
        @root_path = root_path
      end

      def push(mail)
        mail_path = tmp_mail_path(mail)
        open(mail_path, 'w') do |f|
          f.write(mail.encoded)
        end

        File.rename(mail_path, new_mail_path(mail))
      end

      def tmp_mail_path(mail)
        mail_path('tmp', mail)
      end

      def new_mail_path(mail)
        mail_path('new', mail)
      end

      def mail_path(dir, mail)
        File.join(root_path, dir, filename(mail))
      end

      def filename(mail)
        "#{Digest::MD5.hexdigest(mail.message_id)}.eml"
      end

    end
  end
end
