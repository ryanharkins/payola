module Payola
  class SetupIntentSucceeded
    def self.call(event)
      if company = Company.find_by(stripe_setup_intent: event.data.object.id)
        customer_id = company.current_subscription.stripe_customer_id

        # Attach payment method to company subscription
        payment_method = Stripe::PaymentMethod.attach(
          event.data.object.payment_method,
          {
            customer: customer_id,
          }
        )

        # Update subscription card numbers
        Stripe::Customer.update(
          customer_id,
          {
            invoice_settings: {
              default_payment_method: event.data.object.payment_method
            }
          }
        )

        # Update default payment method on subscription
        Stripe::Subscription.update(
          company.current_subscription.stripe_id,
          {
            default_payment_method: event.data.object.payment_method
          }
        )

        # Update card details on subscription model
        pm = Stripe::PaymentMethod.retrieve(event.data.object.payment_method)
        company.current_subscription.update(
          card_last4: pm.card.last4,
          card_expiration: "1-#{pm.card.exp_month}-#{pm.card.exp_year}",
          card_type: pm.card.brand.upcase
        )
      end
    end
  end
end
