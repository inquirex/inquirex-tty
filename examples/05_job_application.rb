# frozen_string_literal: true

# Example 5: Job Application Intake
#
# Two levels of branching with composed rules (all/any).
# The role determines the first branch; experience level and
# specific answers open deeper sub-branches.
# Demonstrates: all(), any(), greater_than, contains, two-level branching.
#
# Run:  bundle exec exe/inquirex-tty run examples/05_job_application.rb

Inquirex::UI.define id: "job-application", version: "1.0.0" do
  meta title: "Job Application", subtitle: "Tell us about yourself"

  start :applicant_name

  ask :applicant_name do
    type :string
    question "What is your full name?"
    widget target: :tty, type: :text_input
    transition to: :role
  end

  ask :role do
    type :enum
    question "Which role are you applying for?"
    options %w[Engineering Design ProductManagement Sales]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :engineering_skills, if_rule: equals(:role, "Engineering")
    transition to: :design_portfolio,   if_rule: equals(:role, "Design")
    transition to: :years_experience
  end

  # --- Engineering branch (level 1) ---

  ask :engineering_skills do
    type :multi_enum
    question "Select your primary skills:"
    options %w[Ruby Python JavaScript Go Rust Java]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :years_experience
  end

  # --- Design branch (level 1) ---

  ask :design_portfolio do
    type :string
    question "Please provide a link to your portfolio:"
    widget target: :tty, type: :text_input
    transition to: :years_experience
  end

  # --- Common: experience (feeds level 2 branching) ---

  ask :years_experience do
    type :integer
    question "How many years of professional experience do you have?"
    widget target: :tty, type: :number_input
    transition to: :leadership_experience, if_rule: greater_than(:years_experience, 7)
    transition to: :education
  end

  # Level 2 branch: senior applicants
  confirm :leadership_experience do
    question "Have you managed a team of 5 or more people?"
    widget target: :tty, type: :yes_no
    transition to: :management_style, if_rule: equals(:leadership_experience, true)
    transition to: :education
  end

  # Level 2 sub-branch: managers
  ask :management_style do
    type :enum
    question "How would you describe your management style?"
    options %w[Collaborative Directive Coaching Delegative]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :education
  end

  ask :education do
    type :enum
    question "What is your highest level of education?"
    options %w[HighSchool Bachelors Masters PhD Bootcamp SelfTaught]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :availability
  end

  ask :availability do
    type :enum
    question "When can you start?"
    options %w[Immediately TwoWeeks OneMonth ThreeMonths]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :referral
  end

  confirm :referral do
    question "Were you referred by a current employee?"
    widget target: :tty, type: :yes_no
    transition to: :referral_name, if_rule: equals(:referral, true)
    transition to: :thanks
  end

  ask :referral_name do
    type :string
    question "Who referred you?"
    widget target: :tty, type: :text_input
    transition to: :thanks
  end

  say :thanks do
    text "Application submitted! We'll be in touch within 5 business days."
  end
end
