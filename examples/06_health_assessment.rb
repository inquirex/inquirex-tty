# frozen_string_literal: true

# Example 6: Health Risk Assessment
#
# Three levels of conditional branching with composed rules.
#
# Level 1: Lifestyle choices branch into exercise, smoking, or diet paths.
# Level 2: Within exercise, intensity level opens a sub-branch.
#          Within smoking, pack count opens a sub-branch.
# Level 3: Heavy smokers with additional risk factors get a deeper follow-up.
#
# Demonstrates: all(), any(), greater_than, less_than, contains, equals,
#               three-level deep conditional logic.
#
# Run:  bundle exec exe/inquirex-tty run examples/06_health_assessment.rb

Inquirex::UI.define id: "health-assessment", version: "1.0.0" do
  meta title: "Health Assessment", subtitle: "Let's assess your health risks"

  start :patient_info

  ask :patient_info do
    type :string
    question "Patient name and date of birth (e.g., Jane Doe, 1985-03-15):"
    widget target: :tty, type: :text_input
    transition to: :lifestyle
  end

  ask :lifestyle do
    type :multi_enum
    question "Select all that apply to your lifestyle:"
    options %w[Exercise Smoking Alcohol HighStress PoorDiet]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :exercise_frequency, if_rule: contains(:lifestyle, "Exercise")
    transition to: :smoking_details,    if_rule: contains(:lifestyle, "Smoking")
    transition to: :diet_details,       if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  # ============================================================
  # LEVEL 1 — Exercise branch
  # ============================================================

  ask :exercise_frequency do
    type :integer
    question "How many days per week do you exercise?"
    widget target: :tty, type: :number_input
    transition to: :exercise_intensity,  if_rule: greater_than(:exercise_frequency, 3)
    transition to: :smoking_details,     if_rule: contains(:lifestyle, "Smoking")
    transition to: :diet_details,        if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  # LEVEL 2 — Intense exerciser sub-branch
  ask :exercise_intensity do
    type :enum
    question "What best describes your typical workout intensity?"
    options %w[Moderate Vigorous Extreme]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    transition to: :injury_history,   if_rule: equals(:exercise_intensity, "Extreme")
    transition to: :smoking_details,  if_rule: contains(:lifestyle, "Smoking")
    transition to: :diet_details,     if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  # LEVEL 3 — Extreme exerciser injury check
  confirm :injury_history do
    question "Have you had any exercise-related injuries in the past year?"
    widget target: :tty, type: :yes_no
    transition to: :smoking_details, if_rule: contains(:lifestyle, "Smoking")
    transition to: :diet_details,    if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  # ============================================================
  # LEVEL 1 — Smoking branch
  # ============================================================

  ask :smoking_details do
    type :integer
    question "How many packs per day do you smoke?"
    widget target: :tty, type: :number_input
    transition to: :smoking_duration, if_rule: greater_than(:smoking_details, 1)
    transition to: :diet_details,     if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  # LEVEL 2 — Heavy smoker sub-branch
  ask :smoking_duration do
    type :integer
    question "How many years have you been smoking?"
    widget target: :tty, type: :number_input
    transition to: :smoking_cessation,
      if_rule: all(
        greater_than(:smoking_duration, 10),
        greater_than(:smoking_details, 1)
      )
    transition to: :diet_details, if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  # LEVEL 3 — Long-term heavy smoker: cessation counseling
  confirm :smoking_cessation do
    question "Have you tried a cessation program before?"
    widget target: :tty, type: :yes_no
    transition to: :cessation_details, if_rule: equals(:smoking_cessation, true)
    transition to: :diet_details,      if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  ask :cessation_details do
    type :string
    question "Please describe what programs you tried and when:"
    widget target: :tty, type: :text_input
    transition to: :diet_details, if_rule: contains(:lifestyle, "PoorDiet")
    transition to: :sleep_quality
  end

  # ============================================================
  # LEVEL 1 — Diet branch
  # ============================================================

  ask :diet_details do
    type :multi_enum
    question "Which of these describe your typical diet?"
    options %w[HighSugar HighSodium LowFiber SkipsMeals FastFood ProcessedFoods]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :sleep_quality
  end

  # ============================================================
  # Common tail
  # ============================================================

  ask :sleep_quality do
    type :enum
    question "How would you rate your sleep quality?"
    options %w[Excellent Good Fair Poor]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    transition to: :mental_health,
      if_rule: any(
        equals(:sleep_quality, "Fair"),
        equals(:sleep_quality, "Poor")
      )
    transition to: :family_history
  end

  ask :mental_health do
    type :multi_enum
    question "Do any of these apply to you?"
    options %w[Anxiety Depression Insomnia ChronicFatigue None]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :family_history
  end

  ask :family_history do
    type :multi_enum
    question "Select any conditions that run in your family:"
    options %w[HeartDisease Diabetes Cancer Hypertension None]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :risk_summary
  end

  say :risk_summary do
    text "Assessment complete. Your responses have been recorded for review by your provider."
  end
end
