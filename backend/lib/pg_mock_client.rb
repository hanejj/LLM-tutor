# frozen_string_literal: true

class PgMockClient
  PaymentResult = Struct.new(:payment_id, :amount, :status, keyword_init: true)

  def initialize(logger: Rails.logger)
    @logger = logger
  end

  # Simulate a card payment. Always succeeds by requirements, but performs light validation.
  # card: { number:, expiry:, cvv: }
  def charge(amount:, card: {}, metadata: {})
    validate_card!(card)
    payment_id = "PAY_#{SecureRandom.hex(8).upcase}"
    @logger.info("[PgMock] charge success id=#{payment_id} amount=#{amount} metadata=#{metadata.inspect}")
    PaymentResult.new(payment_id: payment_id, amount: amount, status: "completed")
  end

  private

  def validate_card!(card)
    number = card[:number].to_s.gsub(/\s+|-/,'')
    expiry = card[:expiry].to_s
    cvv = card[:cvv].to_s

    raise ArgumentError, 'invalid card number' unless number.match?(/^\d{12,19}$/)
    raise ArgumentError, 'invalid expiry' unless expiry.match?(/^\d{2}\/\d{2}$/)
    raise ArgumentError, 'invalid cvv' unless cvv.match?(/^\d{3,4}$/)
  end
end


