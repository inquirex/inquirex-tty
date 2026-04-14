# frozen_string_literal: true

# Example 4: Event Registration
#
# Two levels of conditional logic. The ticket type determines the first
# branch; within VIP there is a further branch based on whether the guest
# wants a plus-one.
# Demonstrates: enum, confirm, equals rule, two-level branching.
#
# Run:  bundle exec exe/inquirex-tty run examples/04_event_registration.rb

Inquirex::UI.define id: "event-registration", version: "1.0.0" do
  meta title: "Event Registration", subtitle: "Register for the conference"

  start :attendee_name

  ask :attendee_name do
    type :string
    question "What is your full name?"
    widget target: :tty, type: :text_input
    transition to: :ticket_type
  end

  ask :ticket_type do
    type :enum
    question "Select your ticket type:"
    options %w[General VIP Speaker]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :vip_options, if_rule: equals(:ticket_type, "VIP")
    transition to: :talk_title,  if_rule: equals(:ticket_type, "Speaker")
    transition to: :dietary
  end

  # --- VIP branch (level 1) ---

  confirm :vip_options do
    question "Would you like to bring a plus-one?"
    widget target: :tty, type: :yes_no
    transition to: :plus_one_name, if_rule: equals(:vip_options, true)
    transition to: :dietary
  end

  # VIP plus-one sub-branch (level 2)
  ask :plus_one_name do
    type :string
    question "What is your plus-one's name?"
    widget target: :tty, type: :text_input
    transition to: :dietary
  end

  # --- Speaker branch (level 1) ---

  ask :talk_title do
    type :string
    question "What is the title of your talk?"
    widget target: :tty, type: :text_input
    transition to: :av_needs
  end

  ask :av_needs do
    type :multi_enum
    question "What A/V equipment do you need?"
    options %w[Projector Microphone Whiteboard ScreenShare None]
    widget target: :tty,     type: :multi_select
    widget target: :desktop, type: :checkbox_group
    transition to: :dietary
  end

  # --- Common path ---

  ask :dietary do
    type :enum
    question "Any dietary restrictions?"
    options %w[None Vegetarian Vegan GlutenFree Halal Kosher]
    widget target: :tty,     type: :select
    widget target: :desktop, type: :radio_group
    widget target: :mobile,  type: :dropdown
    transition to: :confirmation
  end

  say :confirmation do
    text "You're registered! See you at the event."
  end
end
