module Postmark
  class Error < ::StandardError; end

  class HttpClientError < Error
    def retry?
      true
    end
  end

  class HttpServerError < Error
    attr_accessor :status_code, :parsed_body, :body

    alias_method :full_response, :parsed_body

    def self.build(status_code, body)
      parsed_body = Postmark::Json.decode(body) rescue {}

      case status_code
      when '401'
        InvalidApiKeyError.new(401, body, parsed_body)
      when '422'
        ApiInputError.build(body, parsed_body)
      when '500'
        InternalServerError.new(500, body, parsed_body)
      else
        UnexpectedHttpResponseError.new(status_code, body, parsed_body)
      end
    end

    def initialize(status_code = 500, body = '', parsed_body = {})
      self.parsed_body = parsed_body
      self.status_code = status_code.to_i
      self.body = body
      message = parsed_body.fetch('Message', "The Postmark API responded with HTTP status #{status_code}.")

      super(message)
    end

    def retry?
      5 == status_code / 100
    end
  end

  class ApiInputError < HttpServerError
    INACTIVE_RECIPIENT = 406
    INVALID_EMAIL_ADDRESS = 300

    attr_accessor :error_code

    def self.build(body, parsed_body)
      error_code = parsed_body['ErrorCode'].to_i

      case error_code
      when INACTIVE_RECIPIENT
        InactiveRecipientError.new(error_code, body, parsed_body)
      when INVALID_EMAIL_ADDRESS
        InvalidEmailAddressError.new(error_code, body, parsed_body)
      else
        new(error_code, body, parsed_body)
      end
    end

    def initialize(error_code = nil, body = '', parsed_body = {})
      self.error_code = error_code.to_i
      super(422, body, parsed_body)
    end

    def retry?
      false
    end
  end

  class InvalidEmailAddressError < ApiInputError; end

  class InactiveRecipientError < ApiInputError
    attr_reader :recipients

    PATTERNS = [/^Found inactive addresses: (.+?)\.$/.freeze,
                /^Found inactive addresses: (.+?)\.$/.freeze,
                /these inactive addresses: (.+?)\. Inactive/.freeze].freeze

    def self.parse_recipients(message)
      PATTERNS.each do |p|
        _, recipients = p.match(message).to_a
        next unless recipients
        return recipients.split(', ')
      end

      []
    end

    def initialize(*args)
      super
      @recipients = parse_recipients || []
    end

    private

    def parse_recipients
      return unless parsed_body && !parsed_body.empty?

      self.class.parse_recipients(parsed_body['Message'])
    end
  end

  class InvalidTemplateError < Error
    attr_reader :postmark_response

    def initialize(response)
      @postmark_response = response
      super('Failed to render the template. Please check #postmark_response on this error for details.')
    end
  end

  class TimeoutError < Error
    def retry?
      true
    end
  end

  class MailAdapterError < Postmark::Error; end
  class UnknownMessageType < Error; end
  class InvalidApiKeyError < HttpServerError; end
  class InternalServerError < HttpServerError; end
  class UnexpectedHttpResponseError < HttpServerError; end

  # Backwards compatible aliases
  DeliveryError = Error
  InvalidMessageError = ApiInputError
  UnknownError = UnexpectedHttpResponseError
end
