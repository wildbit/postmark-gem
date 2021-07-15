module Postmark
  module MessageHelper

    extend self

    def to_postmark(message = {})
      message = message.dup

      %w(to reply_to cc bcc).each do |field|
        message[field.to_sym] = Array[*message[field.to_sym]].join(", ")
      end

      if message[:headers]
        message[:headers] = headers_to_postmark(message[:headers])
      end

      if message[:attachments]
        message[:attachments] = attachments_to_postmark(message[:attachments])
      end

      if message[:track_links]
        message[:track_links] = ::Postmark::Inflector.to_postmark(message[:track_links])
      end

      HashHelper.to_postmark(message, :keys_to_skip => [:metadata])
    end

    def headers_to_postmark(headers)
      wrap_in_array(headers).map do |item|
        HashHelper.to_postmark(item)
      end
    end

    def attachments_to_postmark(attachments)
      wrap_in_array(attachments).map do |item|
        if item.is_a?(Hash)
          HashHelper.to_postmark(item)
        elsif item.is_a?(File)
          {
            "Name"        => item.path.split("/")[-1],
            "Content"     => encode_in_base64(IO.read(item.path)),
            "ContentType" => "application/octet-stream"
          }
        end
      end
    end

    def encode_in_base64(data)
      [data].pack('m')
    end

    protected

    # From ActiveSupport (Array#wrap)
    def wrap_in_array(object)
      if object.nil?
        []
      elsif object.respond_to?(:to_ary)
        object.to_ary || [object]
      else
        [object]
      end
    end

  end
end