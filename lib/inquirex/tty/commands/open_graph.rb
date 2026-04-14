# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Opens a previously exported Mermaid diagram image in the system viewer.
      class OpenGraph < Dry::CLI::Command
        desc "Open a Mermaid diagram image in the system viewer"

        argument :image_file, required: true, desc: "Path to the image file to open"

        # @param image_file [String]
        # @return [void]
        def call(image_file:, **)
          raise Inquirex::TTY::Error, "File not found: #{image_file}" unless File.exist?(image_file)

          system("open #{Shellwords.escape(image_file)}")
        rescue Inquirex::TTY::Error => e
          warn "Error: #{e.message}"
          exit 1
        end
      end
    end
  end
end
