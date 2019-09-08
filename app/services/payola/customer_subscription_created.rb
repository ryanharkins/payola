module Payola
  class CustomerSubscriptionCreated
    def self.call(event)

      plan = SubscriptionPlan.find_by stripe_id: event.data.object.plan.id
      customer_id = event.data.object.customer
      subscription_id = event.data.object.id
      user = User.find_by(email: Stripe::Customer.retrieve(customer_id).email)

      sub = Payola::Subscription.new do |s|
        s.plan = plan
        s.email = user.email
        s.currency = event.data.object&.plan&.currency ? event.data.object.plan.currency : Payola.default_currency
        s.quantity = event.data.object.quantity
        s.tax_percent = event.data.object.tax_percent
        s.stripe_customer_id = customer_id
        s.stripe_id = subscription_id
        s.owner = user.company
        s.amount = event.data.object.plan.amount
      end

      sub.save!
    end
  end
end
