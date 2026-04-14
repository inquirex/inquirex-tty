# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inquirex::TTY::Commands::Validate do
  subject(:command) { described_class.new }

  let(:hello_flow_path)  { File.expand_path("../../../fixtures/hello_flow.rb", __dir__) }
  let(:sample_flow_path) { File.expand_path("../../../fixtures/sample_flow.rb", __dir__) }

  describe "#call" do
    context "with a valid single-path flow" do
      it "prints success and reports step count" do
        expect { command.call(flow_file: hello_flow_path) }
          .to output(/Flow definition is valid/).to_stdout
      end

      it "includes the start step in output" do
        expect { command.call(flow_file: hello_flow_path) }
          .to output(/Start step:\s+name/).to_stdout
      end
    end

    context "with a valid branching flow" do
      it "prints success" do
        expect { command.call(flow_file: sample_flow_path) }
          .to output(/Flow definition is valid/).to_stdout
      end
    end

    context "when the file does not exist" do
      it "exits with status 1" do
        expect { command.call(flow_file: "/no/such/file.rb") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end
end
