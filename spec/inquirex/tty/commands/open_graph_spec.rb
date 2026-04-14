# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Inquirex::TTY::Commands::OpenGraph do
  subject(:command) { described_class.new }

  describe "#call" do
    context "when the file does not exist" do
      it "exits with status 1" do
        expect { command.call(image_file: "/no/such/file.svg") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end

    context "when the file exists" do
      let(:tmpfile) { Tempfile.new(["graph", ".svg"]) }

      after { tmpfile.close; tmpfile.unlink }

      it "calls system open" do
        allow(command).to receive(:system).and_return(true) # rubocop:disable RSpec/SubjectStub
        command.call(image_file: tmpfile.path)
        expect(command).to have_received(:system).with(/open/) # rubocop:disable RSpec/SubjectStub
      end
    end
  end
end
