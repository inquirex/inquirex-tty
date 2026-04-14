# frozen_string_literal: true

require "inquirex"
require "inquirex/ui"
require "dry/cli"
require "tty-prompt"
require "tty-box"
require "tty-screen"
require "tty-font"
require "pastel"
require "forwardable"
require "json"
require "yaml"
require "time"
require "shellwords"
require "tempfile"

module Inquirex
  # Terminal adapter for Inquirex flows. Renders questions as interactive
  # TTY prompts via tty-prompt, mapping each data type to the appropriate
  # widget via inquirex-ui widget hints.
  #
  # Entry point:
  #   Dry::CLI.new(Inquirex::TTY::Commands).call
  module TTY
    # Raised when inquirex-tty encounters a load, validation, or runtime error.
    class Error < StandardError; end
  end
end

require_relative "tty/version"
require_relative "tty/ui_helper"
require_relative "tty/flow_loader"
require_relative "tty/output_path"
require_relative "tty/renderer"
require_relative "tty/commands/run"
require_relative "tty/commands/validate"
require_relative "tty/commands/graph"
require_relative "tty/commands/export"
require_relative "tty/commands/version"
require_relative "tty/commands"
