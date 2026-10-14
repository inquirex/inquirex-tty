# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

# Runs the real executable as a child process, as a CI job or `lanes init`
# would: nothing stubbed, STDIN closed, the real engine from the bundle. The
# flow has a multi-select gated on its own answer, a step with a default, and
# required steps without one. The answers files leave the defaulted step out,
# so --yes fills it.
RSpec.describe "inquirex-tty run, headless" do
  let(:root)    { File.expand_path("../..", __dir__) }
  let(:exe)     { File.join(root, "exe/inquirex-tty") }
  let(:flow)    { File.join(root, "spec/fixtures/headless/intake_flow.rb") }
  let(:answers) { File.join(root, "spec/fixtures/headless/answers.yml") }

  # @return [Array(String, String, Process::Status)] stdout, stderr, status
  def run_cli(*)
    Open3.popen3(RbConfig.ruby, exe, "run", flow, *, chdir: root) do |stdin, stdout, stderr, wait|
      stdin.close
      out = Thread.new { stdout.read }
      err = Thread.new { stderr.read }
      [out.value, err.value, wait.value]
    end
  end

  it "runs from --answers with no TTY and prints every answer on stdout" do
    out, err, status = run_cli("--answers", answers, "--yes")

    expect(status).to be_success, err
    results = JSON.parse(out)
    expect(results["answers"]).to include(
      "income_types" => %w[w2 rental],
      "rental_count" => 1,
      "client_name"  => "Alan Turing",
      "client_email" => "alan.turing@manchester.edu"
    )
    expect(results["path_taken"]).to eq(%w[welcome income_types rental_count client_name client_email done])
    expect(err).not_to include("{")
  end

  it "reads the same answers from JSON" do
    out, err, status = run_cli("--answers", answers.sub(/\.yml\z/, ".json"), "--yes")

    expect(status).to be_success, err
    expect(JSON.parse(out).dig("answers", "client_name")).to eq("Alan Turing")
  end

  it "writes -o FILE and leaves stdout empty" do
    Dir.mktmpdir("headless") do |dir|
      path = File.join(dir, "results.json")
      out, err, status = run_cli("--answers", answers, "--yes", "-o", path)

      expect(status).to be_success, err
      expect(out).to be_empty
      expect(JSON.parse(File.read(path)).dig("answers", "client_email")).to eq("alan.turing@manchester.edu")
    end
  end

  it "writes -o - to stdout" do
    out, err, status = run_cli("--answers", answers, "--yes", "-o", "-")

    expect(status).to be_success, err
    expect(JSON.parse(out).dig("answers", "income_types")).to eq(%w[w2 rental])
  end

  it "exits non-zero without --yes and names the step the answers leave out" do
    out, err, status = run_cli("--answers", answers)

    expect(status).not_to be_success
    expect(err).to include(":rental_count")
    expect(out).to be_empty
  end

  it "exits non-zero under --yes and names the required step that has no default" do
    out, err, status = run_cli("--answers", File.join(root, "spec/fixtures/headless/partial.yml"), "--yes")

    expect(status).not_to be_success
    expect(err).to include(":client_name")
    expect(out).to be_empty
  end
end
