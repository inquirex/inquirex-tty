# frozen_string_literal: true

RSpec.describe Inquirex::TTY do
  it { is_expected.to be_a(Module) }
  it { expect(Inquirex::TTY::VERSION).not_to be_nil }
  it { expect(Inquirex::TTY::VERSION).to match(/\A\d+\.\d+\.\d+\z/) }
end
