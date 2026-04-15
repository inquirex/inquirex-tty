# frozen_string_literal: true

# Example 1: Hello World
#
# The simplest possible flow — three linear steps, no branching.
# Demonstrates: string input, integer input, say display step.
#
# Run:  bundle exec exe/inquirex-tty run examples/01_hello_world.rb

Inquirex.define id: "hello-world", version: "1.0.0" do
  meta title: "Hello World", subtitle: "A simple introduction"

  start :name

  ask :name do
    type :string
    question "What is your name?"
    widget target: :tty, type: :text_input
    transition to: :age
  end

  ask :age do
    type :integer
    question "How old are you?"
    widget target: :tty, type: :number_input
    transition to: :farewell
  end

  say :farewell do
    text "Thanks for stopping by! Have a great day."
  end
end
