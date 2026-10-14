# frozen_string_literal: true

RSpec.describe Inquirex::TTY do
  it { is_expected.to be_a(Module) }
  it { expect(Inquirex::TTY::VERSION).not_to be_nil }
  it { expect(Inquirex::TTY::VERSION).to match(/\A\d+\.\d+\.\d+\z/) }

  # The renderer calls Engine#back and the run command Inquirex::Headless,
  # both new in core 0.12.0. 0.9.5 shipped a renderer that called a core
  # method missing from the core release it resolved, and every numeric ask
  # raised NoMethodError.
  it "runs against a core that has Engine#back and Headless" do
    expect(Gem.loaded_specs["inquirex"].version).to be >= Gem::Version.new("0.12.0")
  end
end
