# frozen_string_literal: true

# Example 8: Tax Preparer Intake
#
# The most complex example — 18+ steps with multi-level branching,
# enum selections, boolean gates, and free-text collection.
# Demonstrates a real-world intake wizard for a tax preparation service.
#
# Note: The original flowengine example used number_matrix for collecting
# structured numeric data (business types, rental property counts). Inquirex
# uses :string steps for those sections since number_matrix is not part of
# the Inquirex DSL. All rule logic is preserved.
#
# Run:  bundle exec exe/inquirex-tty run examples/08_tax_preparer.rb

Inquirex::UI.define id: "tax-preparer-2025", version: "1.0.0" do
  meta title: "Tax Preparation Intake",
    subtitle: "Help us understand your tax situation"

  start :intro

  # Opening instructions (no input collected)
  say :intro do
    text "Please describe your tax situation in a few sentences.\n" \
         "Do not under any circumstances provide personal information,\n" \
         "such as your address or social security number.\n\n" \
         "Example: I have two W-2s from my two jobs, a rental property, " \
         "and a side business."
    transition to: :filing_status
  end

  ask :filing_status do
    type :enum
    question "What is your filing status for 2025?"
    options({
      "single"                    => "Single",
      "married_filing_jointly"    => "Married Filing Jointly",
      "married_filing_separately" => "Married Filing Separately",
      "head_of_household"         => "Head of Household",
      "widowed"                   => "Widowed"
    })
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group, columns: 1
    widget target: :mobile,  type: :dropdown
    transition to: :dependents
  end

  ask :dependents do
    type :integer
    question "How many dependents do you have?"
    widget target: :tty, type: :number_input
    default 0
    transition to: :income_types
  end

  ask :income_types do
    type :multi_enum
    question "Select all income types that apply to you in 2025."
    options %w[W2 1099 Business Investment Rental Retirement]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :business_count,      if_rule: contains(:income_types, "Business")
    transition to: :investment_details,  if_rule: contains(:income_types, "Investment")
    transition to: :rental_details,      if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  ask :business_count do
    type :integer
    question "How many total businesses do you own or are a partner in?"
    widget target: :tty, type: :number_input
    transition to: :complex_business_info, if_rule: greater_than(:business_count, 2)
    transition to: :business_details
  end

  ask :complex_business_info do
    type :text
    question "With more than 2 businesses, please provide your primary EIN " \
             "and a brief description of each entity."
    widget target: :tty, type: :multiline
    transition to: :business_details
  end

  # Collect counts for each business type (RealEstate, SCorp, CCorp, Trust, LLC)
  ask :business_details do
    type :string
    question "How many of each business type do you own? " \
             "(RealEstate, SCorp, CCorp, Trust, LLC — enter comma-separated counts)"
    widget target: :tty, type: :text_input
    transition to: :investment_details, if_rule: contains(:income_types, "Investment")
    transition to: :rental_details,     if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  ask :investment_details do
    type :multi_enum
    question "What types of investments do you hold?"
    options %w[Stocks Bonds Crypto RealEstate MutualFunds]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :crypto_details,   if_rule: contains(:investment_details, "Crypto")
    transition to: :rental_details,   if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  ask :crypto_details do
    type :text
    question "Please describe your cryptocurrency transactions " \
             "(exchanges used, approximate number of transactions)."
    widget target: :tty, type: :multiline
    transition to: :rental_details, if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  # Collect counts for each rental property type (Residential, Commercial, Vacation)
  ask :rental_details do
    type :string
    question "How many rental properties of each type do you own? " \
             "(Residential, Commercial, Vacation — enter comma-separated counts)"
    widget target: :tty, type: :text_input
    transition to: :state_filing
  end

  ask :state_filing do
    type :multi_enum
    question "Which states do you need to file in?"
    options %w[California NewYork Texas Florida Illinois Other]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :foreign_accounts
  end

  ask :foreign_accounts do
    type :enum
    question "Do you have any foreign financial accounts " \
             "(bank accounts, securities, or financial assets)?"
    options %w[yes no]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    transition to: :foreign_account_details, if_rule: equals(:foreign_accounts, "yes")
    transition to: :deduction_types
  end

  ask :foreign_account_details do
    type :integer
    question "How many foreign accounts do you have?"
    widget target: :tty, type: :number_input
    transition to: :deduction_types
  end

  ask :deduction_types do
    type :multi_enum
    question "Which additional deductions apply to you?"
    options %w[Medical Charitable Education Mortgage None]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :charitable_amount, if_rule: contains(:deduction_types, "Charitable")
    transition to: :client_name
  end

  ask :charitable_amount do
    type :currency
    question "How much did you donate to charity in 2025?"
    widget target: :tty, type: :number_input
    transition to: :charitable_documentation, if_rule: greater_than(:charitable_amount, 5000)
    transition to: :client_name
  end

  ask :charitable_documentation do
    type :text
    question "For charitable contributions over $5,000, please describe " \
             "what sort of paperwork you have available."
    widget target: :tty, type: :multiline
    transition to: :client_name
  end

  ask :client_name do
    type :string
    question "Your name, please:"
    widget target: :tty, type: :text_input
    transition to: :client_email
  end

  ask :client_email do
    type :email
    question "Your email address:"
    widget target: :tty, type: :text_input
    transition to: :thanks
  end

  say :thanks do
    text "Thank you! We will review your information and send you " \
         "a tax preparation estimate within 1-2 business days."
  end
end
