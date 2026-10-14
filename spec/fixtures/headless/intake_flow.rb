# frozen_string_literal: true

# Fixture for spec/integration/headless_run_spec.rb. The multi-select carries
# a skip_if on its own answer: fed through Engine#prefill!, that answer would
# land as a suggestion the rule never sees, and a run with no TTY would stop
# on the question for good.
Inquirex.define id: "headless-intake", version: "1.0.0" do
  meta title: "Headless Intake"

  start :welcome

  say :welcome do
    text "Welcome."
    transition to: :income_types
  end

  ask :income_types do
    type :multi_enum
    question "Which income types apply?"
    options w2: "W-2", rental: "Rental"
    skip_if not_empty(:income_types)
    transition to: :rental_count, if_rule: contains(:income_types, "rental")
    transition to: :client_name
  end

  ask :rental_count do
    type :integer
    question "How many rental properties?"
    default 1
    transition to: :client_name
  end

  ask :client_name do
    type :string
    question "Your name, please:"
    transition to: :client_email
  end

  ask :client_email do
    type :email
    question "Your email address:"
    transition to: :done
  end

  say :done do
    text "Thanks."
  end
end
