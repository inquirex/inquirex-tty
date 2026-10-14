# frozen_string_literal: true

require "spec_helper"
require "tty/prompt/test"

# How the back key interrupts a prompt (plan 010.00, open question 2):
#
# Ctrl-B raises Inquirex::TTY::BackKey::Pressed from a handler registered on
# the prompt's tty-reader for its :keyctrl_b event. tty-reader publishes that
# event from inside every widget's read loop (ask, yes?, select, multi_select,
# enum_select, slider), so one exception unwinds whichever prompt is open. The
# alternative, a TTY::Prompt subclass, would have to override the read loop
# of each widget class separately. The cost of raising is that tty-prompt
# leaves the unwound question subscribed to the reader; Renderer removes the
# listeners it added, and an example below checks that.
#
# These examples drive a real TTY::Prompt::Test, whose input is a StringIO:
# "\C-b" is the byte the terminal sends for Ctrl-B, so the key travels the
# same path through tty-reader that it does at a keyboard.
# Named for the feature (plan 010.00, F1) rather than the method.
# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Inquirex::TTY::Renderer, "#collect" do
  subject(:renderer) { described_class.new(prompt:) }

  let(:prompt) { TTY::Prompt::Test.new }
  let(:engine) { Inquirex::Engine.new(definition) }

  let(:definition) do
    Inquirex.define id: "back-demo" do
      start :name

      ask :name do
        type :string
        question "Your name?"
        transition to: :intro
      end

      say :intro do
        text "Two more."
        transition to: :color
      end

      ask :color do
        type :enum
        question "Favourite colour?"
        options red: "Red", blue: "Blue"
        transition to: :done
      end

      say :done do
        text "Thanks."
      end
    end
  end

  before { allow($stdout).to receive(:puts) }

  # Feeds keystrokes to the prompt, as a user at the keyboard would.
  def type(keys)
    prompt.input << keys
    prompt.input.rewind
  end

  # What the prompt drew, without its colour and cursor escapes.
  def screen = prompt.output.string.gsub(/\e\[[\d;?]*[A-Za-z]/, "")

  # The run loop of `inquirex-tty run`, minus banner and LLM: display steps
  # advance without a keypress so the input below holds only answers.
  def drive
    until engine.finished?
      engine.current_step.display? ? engine.advance : renderer.collect(engine)
    end
  end

  context "when Ctrl-B is pressed on the second question" do
    # name: "Alan" + Enter; colour: Ctrl-B; name again: Enter takes the
    # pre-filled "Alan"; colour: Down + Enter picks Blue.
    before { type("Alan\r\C-b\r\e[B\r") }

    it "returns the engine to the first question" do
      renderer.collect(engine)
      engine.advance # past the :intro display step
      expect(engine.current_step_id).to eq(:color)

      expect(renderer.collect(engine)).to eq(:back)
      expect(engine.current_step_id).to eq(:name)
    end

    it "re-asks the first question with its answer as the default" do
      drive
      expect(screen).to include("Your name? (Alan)")
      expect(engine.answers).to include(name: "Alan", color: "blue")
    end

    it "names the key in a tip line once there is somewhere to go back to" do
      drive
      expect($stdout).to have_received(:puts).with(/Ctrl-B: back to the previous question/).at_least(:once)
    end

    it "leaves no listener of the abandoned question on the reader" do
      drive
      listeners = prompt.reader.send(:local_registrations).map(&:listener)
      expect(listeners.grep(TTY::Prompt::List)).to be_empty
    end
  end

  context "when Ctrl-B is pressed on the first question" do
    before { type("\C-bAlan\r\r") }

    it "changes nothing and keeps the question open" do
      expect(renderer.collect(engine)).to eq(:answered)
      expect(engine.answers).to eq(name: "Alan")
      expect(engine.current_step_id).to eq(:intro)
    end

    it "shows no tip line" do
      renderer.collect(engine)
      expect($stdout).not_to have_received(:puts).with(/Ctrl-B/)
    end
  end

  context "with an LLM step between two questions" do
    let(:definition) do
      Inquirex.define id: "back-llm" do
        start :describe

        ask :describe do
          type :string
          question "Describe yourself."
          transition to: :extracted
        end

        clarify :extracted do
          from :describe
          prompt "Extract."
          schema role: :string
          transition to: :confirm
        end

        confirm :confirm do
          question "All correct?"
          transition to: :done
        end

        say :done do
          text "Thanks."
        end
      end
    end

    before { type("A sysadmin\r\C-b") }

    it "steps over the LLM step to the question before it" do
      renderer.collect(engine)
      engine.answer({ role: "sysadmin" }) # what the adapter would return

      expect(renderer.collect(engine)).to eq(:back)
      expect(engine.current_step_id).to eq(:describe)
      expect(engine.previous_answer(:describe)).to eq("A sysadmin")
    end
  end

  describe "pre-filling each widget from the previous answer" do
    let(:prompt) { instance_double(TTY::Prompt) }

    def node(verb:, type:, options: nil)
      Inquirex::Node.new(
        id:           :test,
        verb:,
        type:,
        question:     "Q?",
        text:         "Q?",
        options:,
        transitions:  [],
        skip_if:      nil,
        default:      nil,
        widget_hints: nil
      )
    end

    it "passes a text answer as the ask default" do
      allow(prompt).to receive(:ask).and_return("Alan")
      renderer.render(node(verb: :ask, type: :string), default: "Alan")
      expect(prompt).to have_received(:ask).with("Q?", default: "Alan")
    end

    it "passes a boolean as the yes? default" do
      allow(prompt).to receive(:yes?).and_return(false)
      renderer.render(node(verb: :confirm, type: :boolean), default: false)
      expect(prompt).to have_received(:yes?).with("Q?", default: false)
    end

    it "preselects a select by the label of the answered value" do
      allow(prompt).to receive(:select).and_return("blue")
      renderer.render(node(verb: :ask, type: :enum, options: { "red" => "Red", "blue" => "Blue" }), default: "blue")
      expect(prompt).to have_received(:select).with("Q?", { "Red" => "red", "Blue" => "blue" }, default: "Blue")
    end

    it "pre-checks a multi_select with the answered values" do
      allow(prompt).to receive(:multi_select).and_return(["blue"])
      options = { "red" => "Red", "blue" => "Blue" }
      renderer.render(node(verb: :ask, type: :multi_enum, options:), default: ["blue"])
      expect(prompt).to have_received(:multi_select)
        .with("Q?", { "Red" => "red", "Blue" => "blue" }, min: 1, default: ["Blue"])
    end

    it "asks without a default when there is no previous answer" do
      allow(prompt).to receive(:ask).and_return("Alan")
      renderer.render(node(verb: :ask, type: :string))
      expect(prompt).to have_received(:ask).with("Q?")
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
