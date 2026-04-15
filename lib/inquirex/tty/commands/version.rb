# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Prints inquirex-tty and inquirex gem versions to stdout.
      class Version < Dry::CLI::Command
        desc "Print version information"

        # @param **_ [Hash] ignored options
        # @return [void]
        def call(**)
          puts "inquirex-tty #{Inquirex::TTY::VERSION}"
          puts "inquirex     #{Inquirex::VERSION}"
        end
      end
    end
  end
end
