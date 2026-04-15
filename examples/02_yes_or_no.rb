# frozen_string_literal: true

# Example 2: Yes or No
#
# A single boolean branch. Answering "yes" takes a detour;
# answering "no" goes straight to the end.
# Demonstrates: confirm verb, equals rule, simple branching.
#
# Run:  bundle exec exe/inquirex-tty run examples/02_yes_or_no.rb

Inquirex.define id: "yes-or-no", version: "1.0.0" do
  meta title: "Yes or No", subtitle: "A simple boolean branch"

  start :has_pet

  confirm :has_pet do
    question "Do you have a pet?"
    widget target: :tty, type: :yes_no
    transition to: :pet_name, if_rule: equals(:has_pet, true)
    transition to: :done
  end

  ask :pet_name do
    type :string
    question "What is your pet's name?"
    widget target: :tty, type: :text_input
    transition to: :done
  end

  say :done do
    text "All done! Thanks for answering."
  end
end
