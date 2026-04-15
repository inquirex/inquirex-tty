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

      it "prints the title from meta" do
        expect { command.call(flow_file: hello_flow_path) }
          .to output(/Title:\s+Hello World/).to_stdout
      end
    end

    context "with a valid branching flow" do
      it "prints success" do
        expect { command.call(flow_file: sample_flow_path) }
          .to output(/Flow definition is valid/).to_stdout
      end

      it "prints the subtitle from meta" do
        expect { command.call(flow_file: sample_flow_path) }
          .to output(/Subtitle:\s+A test fixture/).to_stdout
      end
    end

    context "when the file does not exist" do
      it "exits with status 1" do
        expect { command.call(flow_file: "/no/such/file.rb") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end

      it "writes a human-readable error message to stderr" do
        expect do
          command.call(flow_file: "/no/such/file.rb")
        rescue SystemExit
          # expected
        end.to output(/Error:/).to_stderr
      end
    end

    context "when the flow raises a definition error" do
      before do
        allow(Inquirex::TTY::FlowLoader).to receive(:load)
          .and_raise(Inquirex::Errors::Error, "boom")
      end

      it "exits with status 1 and prints the error" do
        expect do
          command.call(flow_file: hello_flow_path)
        rescue SystemExit
          # expected
        end.to output(/Definition error: boom/).to_stderr
      end
    end

    context "when the flow has validation errors" do
      let(:bad_definition) do
        # Stand-in quacking like an Inquirex::Definition with issues the validator
        # catches: unknown transition target and an orphaned (unreachable) step.
        bad_step = instance_double(
          Inquirex::Node,
          transitions: [instance_double(Inquirex::Transition, target: :nowhere)]
        )
        orphan_step = instance_double(Inquirex::Node, transitions: [])
        definition = instance_double(
          Inquirex::Definition,
          id:            "broken",
          version:       "1.0.0",
          start_step_id: :start,
          step_ids:      %i[start orphan],
          meta:          {}
        )
        allow(definition).to receive(:step).with(:start).and_return(bad_step)
        allow(definition).to receive(:step).with(:orphan).and_return(orphan_step)
        definition
      end

      before do
        allow(Inquirex::TTY::FlowLoader).to receive(:load).and_return(bad_definition)
      end

      it "exits with status 1" do
        expect { command.call(flow_file: hello_flow_path) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end

      it "reports the unknown transition target and the unreachable orphan" do
        expect do
          command.call(flow_file: hello_flow_path)
        rescue SystemExit
          # expected
        end.to output(/transitions to unknown step :nowhere.*unreachable/m).to_stderr
      end
    end

    context "when the start step is missing from step_ids" do
      let(:definition) do
        instance_double(
          Inquirex::Definition,
          id:            "missing-start",
          version:       "1.0.0",
          start_step_id: :ghost,
          step_ids:      [:only_present],
          meta:          nil
        )
      end

      before do
        allow(Inquirex::TTY::FlowLoader).to receive(:load).and_return(definition)
        allow(definition).to receive(:step).with(:only_present)
                                           .and_return(instance_double(Inquirex::Node, transitions: []))
      end

      it "reports the missing start step and exits 1" do
        expect do
          command.call(flow_file: hello_flow_path)
        rescue SystemExit
          # expected
        end.to output(/Start step :ghost not found/).to_stderr
      end
    end
  end
end
