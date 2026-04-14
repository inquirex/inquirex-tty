# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Exports a flow definition as a Mermaid flowchart (stdout or file).
      class Graph < Dry::CLI::Command
        LONG_DESCRIPTION = "Export a flow definition as a Mermaid diagram source, an image, or both.\n  " \
                           "Image generation requires mermaid-cli (npm install -g @mermaid-js/mermaid-cli)\n  " \
                           "which this gem will attempt to install for you if mmdc command is not available.\n\n" \
                           "Example:\n  inquirex graph qualify_dsl.rb --format both --output ~/Desktop --open"

        SHORT_DESCRIPTION = "Export a flow definition as a Mermaid diagram source, an image, or both."

        if ARGV[0] == "graph"
          desc LONG_DESCRIPTION
        else
          desc SHORT_DESCRIPTION
        end

        argument :flow_file,
          required: true,
          desc:     "Path to flow definition (.rb file)"
        option :output,
          aliases: ["-o"],
          desc:    "Output file or a directory (default: stdout)"
        option :format,
          aliases: ["-f"],
          default: "source",
          values:  %w[source image both],
          desc:    "Output format"
        option :open,
          aliases: ["-p"],
          default: false,
          type:    :boolean,
          desc:    "Open the SVG in a system viewer"

        # @param flow_file [String]
        # @param options [Hash]
        # @return [void]
        def call(flow_file:, **options)
          definition = FlowLoader.load(flow_file)
          source = Inquirex::Graph::MermaidExporter.new(definition).export
          format = options[:format] || "source"
          output = options[:output]

          case format
          when "source"
            write_source(source, OutputPath.resolve(flow_file, output, ".mmd"))
          when "image"
            write_image(source, OutputPath.resolve_with_default(flow_file, output, ".png"), options[:open])
          when "both"
            write_source(source, OutputPath.resolve(flow_file, output, ".mmd"))
            write_image(source, OutputPath.resolve_with_default(flow_file, output, ".png"), options[:open])
          end
        rescue Inquirex::TTY::Error => e
          warn "Error: #{e.message}"
          exit 1
        end

        private

        def write_source(source, output_path)
          unless output_path
            $stdout.puts source
            return
          end
          File.write(output_path, source)
          warn "Diagram written to #{output_path}"
        end

        def write_image(source, output_path, open_file)
          ensure_mermaid_cli_installed!

          Tempfile.create(%w[inquirex-graph .mmd]) do |temp|
            temp.write(source)
            temp.flush
            run_system_command!(
              "mmdc -i #{Shellwords.escape(temp.path)} -o #{Shellwords.escape(output_path)}",
              "Failed to generate image (mmdc)"
            )
          end

          warn "Diagram written to #{output_path}"
          open_image_file(output_path) if open_file
        end

        def ensure_mermaid_cli_installed!
          return if command_available?("mmdc")

          warn "Installing @mermaid-js/mermaid-cli..."
          installed = system("npm install -g @mermaid-js/mermaid-cli")
          return if installed && command_available?("mmdc")

          raise Inquirex::TTY::Error,
            "Could not install mermaid-cli. Run: npm install -g @mermaid-js/mermaid-cli"
        end

        def open_image_file(filename)
          run_system_command!(
            "open #{Shellwords.escape(filename)}",
            "Failed to open #{filename}"
          )
        end

        def command_available?(command)
          system("command -v #{command} > /dev/null 2>&1")
        end

        def run_system_command!(command, error_message)
          raise Inquirex::TTY::Error, error_message unless system(command)
        end
      end
    end
  end
end
