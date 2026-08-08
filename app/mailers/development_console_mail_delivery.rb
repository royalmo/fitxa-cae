class DevelopmentConsoleMailDelivery
  def initialize(settings = {})
    @logger = settings[:logger] || Rails.logger
    @output = settings.fetch(:output, Rails.env.development? ? $stdout : nil)
  end

  def deliver!(mail)
    message = message_for(mail)

    write_to_console(message)
  end

  private

  attr_reader :output

  def message_for(mail)
    <<~MESSAGE.chomp

      === Development email delivery ===
      #{header_lines(mail).join("\n")}

      #{mail_body(mail)}
      === End development email delivery ===
    MESSAGE
  end

  def header_lines(mail)
    [
      header_line("From", mail.from),
      header_line("To", mail.to),
      header_line("Cc", mail.cc),
      header_line("Bcc", mail.bcc),
      header_line("Reply-To", mail.reply_to),
      subject_line(mail)
    ].compact
  end

  def header_line(label, values)
    addresses = Array(values).compact_blank
    "#{label}: #{addresses.join(", ")}" if addresses.any?
  end

  def subject_line(mail)
    "Subject: #{mail.subject}"
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
