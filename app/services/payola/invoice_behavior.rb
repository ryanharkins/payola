require 'active_support/concern'

module Payola
  module InvoiceBehavior
    extend ActiveSupport::Concern

    module ClassMethods
      def create_sale_from_event(event)
        invoice = event.data.object

        return unless invoice.charge

        subscription = Payola::Subscription.find_by!(stripe_id: invoice.subscription)
        secret_key = Payola.secret_key_for_sale(subscription)

        stripe_sub = Stripe::Customer.retrieve(subscription.stripe_customer_id, secret_key).subscriptions.retrieve(invoice.subscription, secret_key)
        subscription.sync_with!(stripe_sub)

        sale = create_sale(subscription, invoice)

        charge = Stripe::Charge.retrieve(invoice.charge, secret_key)

        update_sale_with_charge(sale, charge, secret_key)

        return sale, charge
      end

      def create_sale(subscription, invoice)
        Payola::Sale.new do |s|
          s.email = subscription.email
          s.state = 'processing'
          s.owner = subscription
          s.product = subscription.plan
          s.stripe_token = 'invoice'
          s.amount = invoice.total
          s.currency = invoice.currency
        end
      end

      def update_sale_with_charge(sale, charge, secret_key)
        card_details = charge.payment_method_details.card
        sale.stripe_id  = charge.id
        sale.card_type  = card_details.brand
        sale.card_last4 = card_details.last4
        sale.hosted_receipt_url = charge.receipt_url

          card_last4: card_details.last4,
        sale.owner.update(
          card_expiration: "01-#{card_details.exp_month}-#{card_details.exp_year}",
          card_type: card_details.brand.upcase
        )

        if charge.respond_to?(:fee)
          sale.fee_amount = charge.fee
        elsif !charge.balance_transaction.nil?
          balance = Stripe::BalanceTransaction.retrieve(charge.balance_transaction, secret_key)
          sale.fee_amount = balance.fee
        end
      end
    end

  end
end
