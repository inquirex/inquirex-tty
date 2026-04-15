# frozen_string_literal: true

# Example 3: Food Preferences
#
# Multiple independent branches from a single multi_enum step.
# Each selection may activate a different follow-up question.
# Demonstrates: multi_enum, contains rule, multiple transitions.
#
# Run:  bundle exec exe/inquirex-tty run examples/03_food_preferences.rb

Inquirex.define id: "food-preferences", version: "1.0.0" do
  meta title: "Food Preferences", subtitle: "Tell us what you enjoy"

  start :diet

  ask :diet do
    type :multi_enum
    question "Which food categories do you enjoy?"
    options %w[Meat Seafood Vegetarian Vegan Dessert]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    widget target: :mobile,  type: :checkbox_group
    transition to: :meat_preference,    if_rule: contains(:diet, "Meat")
    transition to: :seafood_preference, if_rule: contains(:diet, "Seafood")
    transition to: :dessert_preference, if_rule: contains(:diet, "Dessert")
    transition to: :summary
  end

  ask :meat_preference do
    type :enum
    question "What is your favorite type of meat?"
    options %w[Beef Chicken Pork Lamb]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :seafood_preference, if_rule: contains(:diet, "Seafood")
    transition to: :dessert_preference, if_rule: contains(:diet, "Dessert")
    transition to: :summary
  end

  ask :seafood_preference do
    type :enum
    question "What is your favorite type of seafood?"
    options %w[Salmon Tuna Shrimp Lobster Crab]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :dessert_preference, if_rule: contains(:diet, "Dessert")
    transition to: :summary
  end

  ask :dessert_preference do
    type :enum
    question "What is your favorite dessert?"
    options %w[Cake IceCream Pie Cookies Fruit]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :summary
  end

  say :summary do
    text "Thanks! We've noted your food preferences."
  end
end
