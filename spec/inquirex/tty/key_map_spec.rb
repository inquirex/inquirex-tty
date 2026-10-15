# frozen_string_literal: true

require "spec_helper"
require "tty/prompt/test"

# Drives real tty-prompt widgets through TTY::Prompt::Test, since what matters
# is how KeyMap reads the key events tty-reader actually emits.
RSpec.describe Inquirex::TTY::KeyMap do
  let(:prompt)   { TTY::Prompt::Test.new }
  let(:can_back) { true }
  let(:keys)     { "" }

  before do
    prompt.input << keys
    prompt.input.rewind
  end

  # The widget's answer, or the Navigation action it was interrupted with.
  def outcome(&widget)
    prompt.subscribe(described_class.new(can_back:)) { widget.call(prompt) }
  rescue Inquirex::TTY::Navigation => e
    e.action
  end

  describe ".hint" do
    it { expect(described_class.hint(can_back: true)).to eq("⌫ back · ^S skip · ? keys · ^C abort") }
    it { expect(described_class.hint(can_back: false)).to eq("^S skip · ? keys · ^C abort") }
  end

  context "with a text question" do
    let(:ask) { outcome { |p| p.ask("Name?") } }

    {
      "Backspace on an empty answer"              => ["\x7F",      :back],
      "Backspace after deleting everything typed" => ["a\x7F\x7F", :back],
      "Backspace with text typed"                 => ["ab\x7F\r",  "a"],
      "Ctrl-B with text typed"                    => ["ab\C-b",    :back],
      "? on an empty answer"                      => ["?",         :help],
      "? inside an answer"                        => ["what?\r",   "what?"],
      "Ctrl-S"                                    => ["\x13",      :skip],
      "Ctrl-S with text typed"                    => ["ab\x13",    :skip]
    }.each do |description, (input, expected)|
      context "when pressing #{description}" do
        let(:keys) { input }

        it { expect(ask).to eq(expected) }
      end
    end

    context "when there is nothing to go back to" do
      let(:can_back) { false }
      let(:keys)     { "\x7F\C-bAlan\r" }

      it "ignores the back keys" do
        expect(ask).to eq("Alan")
      end
    end
  end

  context "with a yes/no question" do
    let(:keys) { "\x7F" }

    it { expect(outcome { |p| p.yes?("Ok?") }).to eq(:back) }
  end

  context "with a select list" do
    {
      "Backspace"      => ["\x7F",   :back],
      "?"              => ["?",      :help],
      "Down and Enter" => ["\e[B\r", "b"]
    }.each do |description, (input, expected)|
      context "when pressing #{description}" do
        let(:keys) { input }

        it { expect(outcome { |p| p.select("Pick", %w[a b]) }).to eq(expected) }
      end
    end
  end

  context "with a multi-select list" do
    let(:keys) { "\x7F" }

    it { expect(outcome { |p| p.multi_select("Pick", %w[a b]) }).to eq(:back) }
  end

  context "with an enum_select list" do
    context "when Backspace deletes a typed number" do
      let(:keys) { "2\x7F1\r" }

      it { expect(outcome { |p| p.enum_select("Pick", %w[a b]) }).to eq("a") }
    end

    context "when Backspace is pressed with nothing typed" do
      let(:keys) { "\x7F" }

      it { expect(outcome { |p| p.enum_select("Pick", %w[a b]) }).to eq(:back) }
    end
  end

  context "with a multi-line collector" do
    let(:keys) { "one\r\x7F" }

    it "starts each line empty, so Backspace on the second line goes back" do
      expect(outcome { |p| [p.ask(">"), p.ask(">")] }).to eq(:back)
    end
  end

  describe Inquirex::TTY::Navigation do
    subject(:navigation) { described_class.new(:back) }

    its(:action)  { is_expected.to eq(:back) }
    its(:message) { is_expected.to eq("navigation: back") }
  end
end
