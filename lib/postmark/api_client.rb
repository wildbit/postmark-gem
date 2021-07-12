module Postmark
  class ApiClient < Client
    attr_accessor :max_batch_size

    def initialize(api_token, options = {})
      options = options.dup
      @max_batch_size = options.delete(:max_batch_size) || 500
      super
    end

    def deliver(message_hash = {})
      data = serialize(MessageHelper.to_postmark(message_hash))

      with_retries do
        format_response http_client.post("email", data)
      end
    end

    def deliver_in_batches(message_hashes)
      in_batches(message_hashes) do |batch, offset|
        data = serialize(batch.map { |h| MessageHelper.to_postmark(h) })

        with_retries do
          http_client.post("email/batch", data)
        end
      end
    end

    def deliver_message(message)
      if message.templated?
        raise ArgumentError,
              "Please use #{self.class}#deliver_message_with_template to deliver messages with templates."
      end

      data = serialize(message.to_postmark_hash)

      with_retries do
        response, error = take_response_of { http_client.post("email", data) }
        update_message(message, response)
        raise error if error
        format_response(response, true)
      end
    end

    def deliver_message_with_template(message)
      raise ArgumentError, 'Templated delivery requested, but the template is missing.' unless message.templated?

      data = serialize(message.to_postmark_hash)

      with_retries do
        response, error = take_response_of { http_client.post("email/withTemplate", data) }
        update_message(message, response)
        raise error if error
        format_response(response, true)
      end
    end

    def deliver_messages(messages)
      if messages.any? { |m| m.templated? }
        raise ArgumentError,
              "Some of the provided messages have templates. Please use " \
              "#{self.class}#deliver_messages_with_templates to deliver those."
      end

      in_batches(messages) do |batch, offset|
        data = serialize(batch.map { |m| m.to_postmark_hash })

        with_retries do
          http_client.post("email/batch", data).tap do |response|
            response.each_with_index do |r, i|
              update_message(messages[offset + i], r)
            end
          end
        end
      end
    end

    def deliver_messages_with_templates(messages)
      unless messages.all? { |m| m.templated? }
        raise ArgumentError, 'Templated delivery requested, but one or more messages lack templates.'
      end

      in_batches(messages) do |batch, offset|
        mapped = batch.map { |m| m.to_postmark_hash }
        data = serialize(:Messages => mapped)

        with_retries do
          http_client.post("email/batchWithTemplates", data).tap do |response|
            response.each_with_index do |r, i|
              update_message(messages[offset + i], r)
            end
          end
        end
      end
    end

    def delivery_stats
      response = format_response(http_client.get("deliverystats"), true)

      if response[:bounces]
        response[:bounces] = format_response(response[:bounces])
      end

      response
    end

    def messages(options = {})
      path, name, params = extract_messages_path_and_params(options)
      find_each(path, name, params)
    end

    def get_messages(options = {})
      path, name, params = extract_messages_path_and_params(options)
      load_batch(path, name, params).last
    end

    def get_messages_count(options = {})
      path, _, params = extract_messages_path_and_params(options)
      get_resource_count(path, params)
    end

    def get_message(id, options = {})
      get_for_message('details', id, options)
    end

    def dump_message(id, options = {})
      get_for_message('dump', id, options)
    end

    def bounces(options = {})
      find_each('bounces', 'Bounces', options)
    end

    def get_bounces(options = {})
      _, batch = load_batch('bounces', 'Bounces', options)
      batch
    end

    def get_bounce(id)
      format_response http_client.get("bounces/#{id}")
    end

    def dump_bounce(id)
      format_response http_client.get("bounces/#{id}/dump")
    end

    def activate_bounce(id)
      format_response http_client.put("bounces/#{id}/activate")["Bounce"]
    end

    def opens(options = {})
      find_each('messages/outbound/opens', 'Opens', options)
    end

    def clicks(options = {})
      find_each('messages/outbound/clicks', 'Clicks', options)
    end

    def get_opens(options = {})
      _, batch = load_batch('messages/outbound/opens', 'Opens', options)
      batch
    end

    def get_clicks(options = {})
      _, batch = load_batch('messages/outbound/clicks', 'Clicks', options)
      batch
    end

    def get_opens_by_message_id(message_id, options = {})
      _, batch = load_batch("messages/outbound/opens/#{message_id}",
                            'Opens',
                            options)
      batch
    end

    def get_clicks_by_message_id(message_id, options = {})
      _, batch = load_batch("messages/outbound/clicks/#{message_id}",
                            'Clicks',
                            options)
      batch
    end

    def opens_by_message_id(message_id, options = {})
      find_each("messages/outbound/opens/#{message_id}", 'Opens', options)
    end

    def clicks_by_message_id(message_id, options = {})
      find_each("messages/outbound/clicks/#{message_id}", 'Clicks', options)
    end

    def create_trigger(type, options)
      type = Postmark::Inflector.to_postmark(type).downcase
      data = serialize(HashHelper.to_postmark(options))
      format_response http_client.post("triggers/#{type}", data)
    end

    def get_trigger(type, id)
      format_response http_client.get("triggers/#{type}/#{id}")
    end

    def delete_trigger(type, id)
      type = Postmark::Inflector.to_postmark(type).downcase
      format_response http_client.delete("triggers/#{type}/#{id}")
    end

    def get_triggers(type, options = {})
      type = Postmark::Inflector.to_postmark(type)
      _, batch = load_batch("triggers/#{type.downcase}", type, options)
      batch
    end

    def triggers(type, options = {})
      type = Postmark::Inflector.to_postmark(type)
      find_each("triggers/#{type.downcase}", type, options)
    end

    def server_info
      format_response http_client.get("server")
    end

    def update_server_info(attributes = {})
      data = HashHelper.to_postmark(attributes)
      format_response http_client.put("server", serialize(data))
    end

    def get_templates(options = {})
      load_batch('templates', 'Templates', options)
    end

    def templates(options = {})
      find_each('templates', 'Templates', options)
    end

    def get_template(id)
      format_response http_client.get("templates/#{id}")
    end

    def create_template(attributes = {})
      data = serialize(HashHelper.to_postmark(attributes))

      format_response http_client.post('templates', data)
    end

    def update_template(id, attributes = {})
      data = serialize(HashHelper.to_postmark(attributes))

      format_response http_client.put("templates/#{id}", data)
    end

    def delete_template(id)
      format_response http_client.delete("templates/#{id}")
    end

    def validate_template(attributes = {})
      data = serialize(HashHelper.to_postmark(attributes))
      response = format_response(http_client.post('templates/validate', data))

      response.each do |k, v|
        next unless v.is_a?(Hash) && k != :suggested_template_model

        response[k] = HashHelper.to_ruby(v)

        if response[k].has_key?(:validation_errors)
          ruby_hashes = response[k][:validation_errors].map do |err|
            HashHelper.to_ruby(err)
          end
          response[k][:validation_errors] = ruby_hashes
        end
      end

      response
    end

    def deliver_with_template(attributes = {})
      data = serialize(MessageHelper.to_postmark(attributes))

      with_retries do
        format_response http_client.post('email/withTemplate', data)
      end
    end

    def deliver_in_batches_with_templates(message_hashes)
      in_batches(message_hashes) do |batch, offset|
        mapped = batch.map { |h| MessageHelper.to_postmark(h) }
        data = serialize(:Messages => mapped)

        with_retries do
          http_client.post('email/batchWithTemplates', data)
        end
      end
    end

    def get_stats_totals(options = {})
      format_response(http_client.get('stats/outbound', options))
    end

    def get_stats_counts(stat, options = {})
      url = "stats/outbound/#{stat}"
      url << "/#{options[:type]}" if options.has_key?(:type)

      response = format_response(http_client.get(url, options))
      response[:days].map! { |d| HashHelper.to_ruby(d) }
      response
    end

    def get_webhooks(options = {})
      options = HashHelper.to_postmark(options)
      _, batch = load_batch('webhooks', 'Webhooks', options)
      batch
    end

    def get_webhook(id)
      format_response http_client.get("webhooks/#{id}")
    end

    def create_webhook(attributes = {})
      data = serialize(HashHelper.to_postmark(attributes))

      format_response http_client.post('webhooks', data)
    end

    def update_webhook(id, attributes = {})
      data = serialize(HashHelper.to_postmark(attributes))

      format_response http_client.put("webhooks/#{id}", data)
    end

    def delete_webhook(id)
      format_response http_client.delete("webhooks/#{id}")
    end

    def get_message_streams(options = {})
      _, batch = load_batch('message-streams', 'MessageStreams', options)
      batch
    end

    def message_streams(options = {})
      find_each('message-streams', 'MessageStreams', options)
    end

    def get_message_stream(id)
      format_response(http_client.get("message-streams/#{id}"))
    end

    def create_message_stream(attributes = {})
      data = serialize(HashHelper.to_postmark(attributes))
      format_response(http_client.post('message-streams', data))
    end

    def update_message_stream(id, attributes)
      data = serialize(HashHelper.to_postmark(attributes))
      format_response(http_client.patch("message-streams/#{id}", data))
    end

    def archive_message_stream(id)
      format_response http_client.post("message-streams/#{id}/archive")
    end

    def unarchive_message_stream(id)
      format_response http_client.post("message-streams/#{id}/unarchive")
    end

    def dump_suppressions(stream_id, options = {})
      _, batch = load_batch("message-streams/#{stream_id}/suppressions/dump", 'Suppressions', options)
      batch
    end

    def create_suppressions(stream_id, email_addresses)
      data = serialize(:Suppressions => Array(email_addresses).map { |e| HashHelper.to_postmark(:email_address => e) })
      format_response(http_client.post("message-streams/#{stream_id}/suppressions", data))
    end

    def delete_suppressions(stream_id, email_addresses)
      data = serialize(:Suppressions => Array(email_addresses).map { |e| HashHelper.to_postmark(:email_address => e) })
      format_response(http_client.post("message-streams/#{stream_id}/suppressions/delete", data))
    end

    protected

    def in_batches(messages)
      r = messages.each_slice(max_batch_size).each_with_index.map do |batch, i|
        yield batch, i * max_batch_size
      end

      format_response r.flatten
    end

    def update_message(message, response)
      response ||= {}
      message['X-PM-Message-Id'] = response['MessageID']
      message.delivered = response['ErrorCode'] && response['ErrorCode'].zero?
      message.postmark_response = response
    end

    def get_for_message(action, id, options = {})
      path, _, params = extract_messages_path_and_params(options)
      format_response http_client.get("#{path}/#{id}/#{action}", params)
    end

    def extract_messages_path_and_params(options = {})
      options = options.dup
      messages_key = options[:inbound] ? 'InboundMessages' : 'Messages'
      path = options.delete(:inbound) ? 'messages/inbound' : 'messages/outbound'
      [path, messages_key, options]
    end
  end
end
