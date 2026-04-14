# frozen_string_literal: true

# Branching fixture used by validate_spec and renderer_spec.
Inquirex::UI.define id: "sample", version: "1.0.0" do
  meta title: "Sample Flow", subtitle: "A test fixture"

  start :has_pet

  confirm :has_pet do
    question "Do you have a pet?"
    transition to: :pet_type, if_rule: equals(:has_pet, true)
    transition to: :done
  end

  ask :pet_type do
    type :enum
    question "What kind of pet?"
    options %w[Dog Cat Bird Fish Other]
    widget target: :tty, type: :select
    transition to: :done
  end

  say :done do
    text "Thanks for sharing!"
  end
end
