# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inquirex::TTY::UIHelper do
  let(:klass) do
    Class.new do
      include Inquirex::TTY::UIHelper
    end
  end
  let(:instance) { klass.new }

  before { allow($stdout).to receive(:puts) }

  describe "#pastel" do
    subject { instance.pastel }

    it { is_expected.to be_a(Pastel::Delegator).or be_a(Pastel::Detached).or respond_to(:yellow) }
  end

  describe "#box" do
    it "outputs a bordered box" do
      instance.box("Hello", title: "Test")
      expect($stdout).to have_received(:puts).at_least(:once)
    end
  end

  describe "#sep" do
    it "outputs a separator line" do
      instance.sep(:yellow, "━")
      expect($stdout).to have_received(:puts).with(a_string_including("━"))
    end
  end

  describe "#next_step" do
    it "outputs step progress" do
      instance.next_step(:my_step, 3)
      expect($stdout).to have_received(:puts).with(a_string_including("Step 3"))
    end
  end

  describe "#width" do
    subject { instance.width }

    it { is_expected.to be_a(Integer) }
    it { is_expected.to be > 0 }
  end

  describe "TTY::Box wrappers" do
    %i[info success error warning].each do |method|
      describe "##{method}" do
        it "outputs a styled box" do
          instance.send(method, "test message")
          expect($stdout).to have_received(:puts).at_least(:once)
        end
      end
    end
  end
end
