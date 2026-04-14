# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inquirex::TTY::Commands::Version do
  subject(:command) { described_class.new }

  describe "#call" do
    it "outputs the inquirex-tty version" do
      expect { command.call }.to output(/inquirex-tty\s+#{Regexp.escape(Inquirex::TTY::VERSION)}/).to_stdout
    end

    it "outputs the inquirex core version" do
      expect { command.call }.to output(/inquirex\s+#{Regexp.escape(Inquirex::VERSION)}/).to_stdout
    end

    it "outputs the inquirex-ui version" do
      expect { command.call }.to output(/inquirex-ui\s+#{Regexp.escape(Inquirex::UI::VERSION)}/).to_stdout
    end
  end
end
