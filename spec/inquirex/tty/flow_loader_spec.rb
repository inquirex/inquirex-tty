# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Inquirex::TTY::FlowLoader do
  let(:hello_flow_path) { File.expand_path("../../fixtures/hello_flow.rb", __dir__) }

  describe ".load" do
    subject { described_class.load(hello_flow_path) }

    it { is_expected.to be_a(Inquirex::Definition) }
    its(:id) { is_expected.to eq("hello-world") }
    its(:start_step_id) { is_expected.to eq(:name) }
    its(:step_ids)     { is_expected.to include(:name, :farewell) }
  end

  describe "#initialize" do
    subject(:loader) { described_class.new(path) }

    context "when file exists and ends in .rb" do
      let(:path) { hello_flow_path }

      it { is_expected.to be_a(described_class) }
    end

    context "when file does not exist" do
      let(:path) { File.join(Dir.tmpdir, "no_such_flow_#{rand(100_000)}.rb") }

      it "raises Inquirex::TTY::Error with File not found" do
        expect { loader }.to raise_error(Inquirex::TTY::Error, /File not found/)
      end
    end

    context "when file has a non-.rb extension" do
      let!(:tmp_file) do
        f = Tempfile.new(["flow", ".json"])
        f.write("{}")
        f.close
        f
      end
      let(:path) { tmp_file.path }

      after { tmp_file.unlink }

      it "raises Inquirex::TTY::Error with Not a .rb file" do
        expect { loader }.to raise_error(Inquirex::TTY::Error, /Not a \.rb file/)
      end
    end
  end

  describe "#load" do
    subject(:definition) { described_class.new(hello_flow_path).load }

    it { is_expected.to be_a(Inquirex::Definition) }
    its(:id)            { is_expected.to eq("hello-world") }
    its(:start_step_id) { is_expected.to eq(:name) }

    context "when the file has a syntax error" do
      let!(:bad_file) do
        f = Tempfile.new(["bad_flow", ".rb"])
        f.write("def unclosed_method")
        f.close
        f
      end

      after { bad_file.unlink }

      it "raises Inquirex::TTY::Error with Syntax error" do
        expect { described_class.new(bad_file.path).load }
          .to raise_error(Inquirex::TTY::Error, /Syntax error/)
      end
    end
  end
end
