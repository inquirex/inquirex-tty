# frozen_string_literal: true

# Two collecting steps (one required, one optional) and a display step, for
# the back / skip / help navigation specs in run_spec.
Inquirex.define id: "back-flow", version: "1.0.0" do
  meta title: "Back"

  start :name

  ask :name do
    type :string
    question "What is your name?"
    transition to: :nickname
  end

  ask :nickname do
    type :string
    question "Any nickname?"
    optional
    transition to: :done
  end

  say :done do
    text "Done."
  end
end
