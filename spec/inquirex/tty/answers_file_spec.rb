# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inquirex::TTY::AnswersFile do
  let(:dir) { Dir.mktmpdir("answers") }

  after { FileUtils.rm_rf(dir) }

  def write(name, text)
    File.join(dir, name).tap { |path| File.write(path, text) }
  end

  it "reads JSON" do
    path = write("answers.json", '{"client_name": "Alan Turing", "income_types": ["w2", "rental"]}')
    expect(described_class.load(path)).to eq("client_name" => "Alan Turing", "income_types" => %w[w2 rental])
  end

  %w[yml yaml].each do |extension|
    it "reads YAML from a .#{extension} file" do
      path = write("answers.#{extension}", "client_name: Alan Turing\nincome_types: [w2, rental]\n")
      expect(described_class.load(path)).to eq("client_name" => "Alan Turing", "income_types" => %w[w2 rental])
    end
  end

  it "refuses an unknown extension" do
    path = write("answers.txt", "client_name: Alan Turing\n")
    expect { described_class.load(path) }.to raise_error(Inquirex::TTY::Error, /must be \.json, \.yml or \.yaml/)
  end

  it "refuses a missing file" do
    expect { described_class.load(File.join(dir, "none.json")) }
      .to raise_error(Inquirex::TTY::Error, /not found/)
  end

  it "refuses a file that does not parse" do
    path = write("answers.json", "{not json")
    expect { described_class.load(path) }.to raise_error(Inquirex::TTY::Error, /Cannot parse/)
  end

  it "refuses a document that is not a mapping" do
    path = write("answers.yml", "- Alan Turing\n")
    expect { described_class.load(path) }.to raise_error(Inquirex::TTY::Error, /must map step ids/)
  end

  it "refuses YAML tags that would build objects" do
    path = write("answers.yml", "client: !ruby/object:OpenStruct {}\n")
    expect { described_class.load(path) }.to raise_error(Inquirex::TTY::Error, /Cannot parse/)
  end
end
