# frozen_string_literal: true

# Example 7: Loan Application
#
# Three levels of conditional branching with composed rules (all, any).
#
# Level 1: Loan type (Personal / Mortgage / Business) splits into paths.
# Level 2: Within Mortgage, property value triggers a high-value branch.
#          Within Business, revenue level triggers sub-branches.
# Level 3: Investment property jumbo loan review; established corp expansion.
#
# Note: The original flowengine example used number_matrix for collecting
# structured numeric data. Inquirex uses :string steps for the same steps
# since number_matrix is not part of the Inquirex DSL.
#
# Demonstrates: all(), any(), greater_than, less_than, equals,
#               three-level deep conditional logic.
#
# Run:  bundle exec exe/inquirex-tty run examples/07_loan_application.rb

Inquirex.define id: "loan-application", version: "1.0.0" do
  meta title: "Loan Application", subtitle: "Let's find the right loan for you"

  start :applicant_info

  ask :applicant_info do
    type :string
    question "Full legal name:"
    widget target: :tty, type: :text_input
    transition to: :loan_type
  end

  ask :loan_type do
    type :enum
    question "What type of loan are you applying for?"
    options %w[Personal Mortgage Business]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :personal_amount,   if_rule: equals(:loan_type, "Personal")
    transition to: :mortgage_property, if_rule: equals(:loan_type, "Mortgage")
    transition to: :business_info,     if_rule: equals(:loan_type, "Business")
  end

  # ============================================================
  # LEVEL 1 — Personal loan (simple path)
  # ============================================================

  ask :personal_amount do
    type :currency
    question "How much would you like to borrow (in dollars)?"
    widget target: :tty, type: :number_input
    transition to: :personal_purpose
  end

  ask :personal_purpose do
    type :enum
    question "What is the primary purpose of this loan?"
    options %w[DebtConsolidation HomeImprovement Medical Travel Education Other]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :credit_check
  end

  # ============================================================
  # LEVEL 1 — Mortgage branch
  # ============================================================

  ask :mortgage_property do
    type :enum
    question "What type of property is this for?"
    options %w[SingleFamily Condo Townhouse MultiFamily Commercial]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :mortgage_amount
  end

  ask :mortgage_amount do
    type :currency
    question "What is the estimated property value (in dollars)?"
    widget target: :tty, type: :number_input
    transition to: :mortgage_high_value, if_rule: greater_than(:mortgage_amount, 750_000)
    transition to: :down_payment
  end

  # LEVEL 2 — High-value mortgage
  confirm :mortgage_high_value do
    question "Will this be your primary residence?"
    widget target: :tty, type: :yes_no
    transition to: :jumbo_review,
      if_rule: all(
        equals(:mortgage_high_value, false),
        greater_than(:mortgage_amount, 750_000)
      )
    transition to: :down_payment
  end

  # LEVEL 3 — Investment property jumbo loan details
  ask :jumbo_review do
    type :string
    question "Provide details about your existing properties " \
             "(OwnedProperties, RentalProperties, MortgagesOwed — comma-separated counts):"
    widget target: :tty, type: :text_input
    transition to: :down_payment
  end

  ask :down_payment do
    type :currency
    question "How much is your down payment (in dollars)?"
    widget target: :tty, type: :number_input
    transition to: :credit_check
  end

  # ============================================================
  # LEVEL 1 — Business loan branch
  # ============================================================

  ask :business_info do
    type :string
    question "Business name and EIN:"
    widget target: :tty, type: :text_input
    transition to: :business_type
  end

  ask :business_type do
    type :enum
    question "Business structure:"
    options %w[SoleProprietor LLC SCorp CCorp Partnership]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :annual_revenue
  end

  ask :annual_revenue do
    type :currency
    question "What is your annual revenue (in dollars)?"
    widget target: :tty, type: :number_input
    transition to: :startup_details,     if_rule: less_than(:annual_revenue, 100_000)
    transition to: :established_details, if_rule: greater_than(:annual_revenue, 500_000)
    transition to: :business_loan_amount
  end

  # LEVEL 2 — Startup path
  ask :startup_details do
    type :integer
    question "How many months has the business been operating?"
    widget target: :tty, type: :number_input
    transition to: :startup_funding, if_rule: less_than(:startup_details, 12)
    transition to: :business_loan_amount
  end

  # LEVEL 3 — Very new startup
  ask :startup_funding do
    type :multi_enum
    question "What funding sources have you used so far?"
    options %w[PersonalSavings FriendsFamily AngelInvestor VentureCapital Grant CreditCards None]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :business_loan_amount
  end

  # LEVEL 2 — Established business path
  ask :established_details do
    type :string
    question "Provide key financial figures " \
             "(Employees, AnnualExpenses, OutstandingDebt — comma-separated values):"
    widget target: :tty, type: :text_input
    transition to: :established_expansion,
      if_rule: all(
        greater_than(:annual_revenue, 500_000),
        any(
          equals(:business_type, "CCorp"),
          equals(:business_type, "SCorp")
        )
      )
    transition to: :business_loan_amount
  end

  # LEVEL 3 — Corp expansion review
  ask :established_expansion do
    type :multi_enum
    question "What will the loan fund?"
    options %w[Hiring Equipment RealEstate Acquisition Marketing RAndD]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :business_loan_amount
  end

  ask :business_loan_amount do
    type :currency
    question "How much funding are you requesting (in dollars)?"
    widget target: :tty, type: :number_input
    transition to: :credit_check
  end

  # ============================================================
  # Common tail
  # ============================================================

  confirm :credit_check do
    question "Do you authorize a credit check?"
    widget target: :tty, type: :yes_no
    transition to: :review, if_rule: equals(:credit_check, true)
    transition to: :declined
  end

  say :declined do
    text "A credit check is required to proceed. Your application has been saved as a draft."
  end

  say :review do
    text "Application submitted! You will receive a decision within 3-5 business days."
  end
end
