require 'inquirex-llm'

Inquirex.define id: "llm-test", version: "1.0.0" do
  meta title: "Test of Extract Keyword",
    subtitle: "This form extracts structured data from an unstructured text description."

  start :describe

  ask :describe do
    type :text
    question "Describe your 2025 tax situation."
    transition to: :summary
  end

  extract :summary do
    from :describe
    prompt "Extract: filing_status, dependents, income_types, state_filing."
    schema filing_status: :string,
      dependents:    :integer,
      income_types:  :multi_enum,
      state_filing:  :string
    model :claude_sonnet
    transition to: :filing_status
  end

  ask :filing_status do
    type :enum
    question "Filing status?"
    options %w[single married_filing_jointly head_of_household]
    skip_if not_empty(:filing_status) # ← the whole trick
    transition to: :dependents
  end

  ask :dependents do
    type :integer
    question "How many dependents?"
    skip_if not_empty(:dependents)
    transition to: :income_types
  end

  ask :income_types do
    type :multi_enum
    question "Select all income types that apply to you in 2025."
    options %w[W2 1099 Business Investment Rental Retirement]
    widget target: :tty, type: :multi_select
    skip_if not_empty(:income_types)
    transition to: :thanks
  end

  say :thanks do
    text "Thanks for filling this out! Have a great day!"
  end
end
