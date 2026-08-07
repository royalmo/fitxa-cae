class DevelopmentConsoleMailDelivery
  def initialize(settings = {})
    @logger = settings[:logger] || Rails.logger
    @output = settings.fetch(:output, Rails.env.development? ? $stdout : nil)
  end

  def deliver!(mail)
    message = message_for(mail)

    logger.info(message)
    write_to_console(message)
  end

  private

  attr_reader :logger, :output

  def message_for(mail)
    <<~MESSAGE

      === Development email delivery ===
      From: #{Array(mail.from).join(", ")}
      To: #{Array(mail.to).join(", ")}
      Reply-To: #{Array(mail.reply_to).join(", ")}
      Subject: #{mail.subject}

      #{mail_body(mail)}
      === End development email delivery ===
    MESSAGE
  end

  def mail_body(mail)
    part = mail.text_part || mail.html_part
    body = part ? part.body : mail.body

    body.decoded.to_s.strip
  end

  def write_to_console(message)
    return unless output

    output.write(message)
    output.flush if output.respond_to?(:flush)
  end
end
