# frozen_string_literal: true

# Example 09: Tax Preparer Intake with LLM-assisted pre-fill
#
# The thesis:
#   "Deterministic DSL defines what data you need.
#    LLM extracts what it can from one free-text answer.
#    The engine only asks what's left."
#
# Flow:
#   1. :describe      — one open-ended question
#   2. :extracted     — clarify step; LLM returns structured fields
#   3. :filing_status, :dependents, :income_types, :state_filing, :client_contact
#                     — asked only when the LLM left the field blank
#   4. :summary       — LLM produces a complexity / fee summary over everything
#   5. :done          — farewell
#
# Run:
#   bundle exec exe/inquirex-tty run examples/09_tax_preparer_llm.rb
#
# Uses ANTHROPIC_API_KEY from .env (or any parent .env) for live Claude calls.
# Falls back to Inquirex::LLM::NullAdapter when the key is absent, or when
# INQUIREX_LLM_ADAPTER=null is set.

require "inquirex"
require "inquirex/llm"

Inquirex.define id: "tax-preparer-llm-2025", version: "1.0.0" do
  meta title: "Tax Prep Intake (LLM-assisted)",
    subtitle: "Tell us about your tax situation — we'll only ask what we can't figure out"

  start :describe

  ask :describe do
    type :text
    question "Please describe your 2025 tax situation in your own words.\n" \
             "Mention filing status, kids/dependents, income sources\n" \
             "(W-2, business, rental, investments, crypto), and your state.\n" \
             "Do NOT include SSN or home address."
    widget target: :tty, type: :multiline
    transition to: :extracted
  end

  clarify :extracted do
    from :describe
    prompt <<~PROMPT
      You are a tax-prep intake assistant. Extract structured information from
      the client's free-text description.

      STRICT VALUE RULES — you MUST use these exact string literals, no others:

      filing_status: exactly ONE of:
        "single" | "married_filing_jointly" | "married_filing_separately"
        | "head_of_household" | "widowed"
      Use "" (empty string) if the client did not indicate a filing status.

      dependents: integer count of dependents (0 if client said they have none;
      null only if the client made no mention of dependents at all).

      income_types: array. Each element MUST be ONE of these exact tokens
      (case-sensitive, no hyphens, no spaces, no variants):
        "W2"          — W-2 employment / regular salary / wage job
        "1099"        — 1099 contracting / freelance / gig work
        "Business"    — self-employment, LLC, S-corp, C-corp, sole-prop, partnership, consulting business
        "Investment"  — stocks, bonds, crypto, mutual funds, dividends, capital gains
        "Rental"      — rental property income (residential, commercial, or vacation)
        "Retirement"  — 401(k), IRA, pension, social-security income
      Do NOT output "W-2", "self-employment", "self_employment", "rental income",
      "investments", or any variant — use only the tokens listed above.
      Use [] if the client mentioned no income types.

      state_filing: the primary US state as a capitalized English name
      ("California", "New York", "Texas"). Use "" if unmentioned.

      IMPORTANT: Only include a value when the client's text gives you concrete
      evidence. Do NOT infer or guess. Use null / "" / [] liberally.
    PROMPT
    schema filing_status: :string,
      dependents:    :integer,
      income_types:  :multi_enum,
      state_filing:  :string
    model :claude_sonnet
    temperature 0.0
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
    widget target: :tty, type: :select
    skip_if not_empty(:filing_status)
    transition to: :dependents
  end

  ask :dependents do
    type :integer
    question "How many dependents do you have?"
    widget target: :tty, type: :number_input
    default 0
    skip_if not_empty(:dependents)
    transition to: :income_types
  end

  ask :income_types do
    type :multi_enum
    question "Select all income types that apply to you in 2025."
    options %w[W2 1099 Business Investment Rental Retirement]
    widget target: :tty, type: :multi_select
    skip_if not_empty(:income_types)
    transition to: :state_filing
  end

  ask :state_filing do
    type :string
    question "Which state do you need to file in?"
    widget target: :tty, type: :text_input
    skip_if not_empty(:state_filing)
    transition to: :client_contact
  end

  ask :client_contact do
    type :string
    question "Your name and email (so we can send the quote)?"
    widget target: :tty, type: :text_input
    transition to: :summary
  end

  summarize :summary do
    from_all
    prompt <<~PROMPT
      Based on the collected answers, produce a concise JSON object with:
        - complexity: "simple" | "moderate" | "complex"
        - fee_estimate_low:  integer USD
        - fee_estimate_high: integer USD
        - red_flags: array of short strings (empty array if none)
        - notes: one-sentence summary for the preparer
    PROMPT
    transition to: :done
  end

  say :done do
    text "Thank you! A tax professional will review your intake and reach out."
  end
end
