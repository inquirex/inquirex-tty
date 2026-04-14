# rubocop:disable Layout/LineContinuationLeadingSpace
# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Exports a flow definition as a Mermaid flowchart (stdout or file).
      class Graph < Dry::CLI::Command
        desc "Export a flow definition as a Mermaid diagram source, an image, or both.\n" \
             "  Image generation requires mermaid-cli (npm install -g @mermaid-js/mermaid-cli)\n" \
             "  which this gem will attempt to install for you if mmdc command is not available.\n\n" \
             "Example:\n  inquirex graph qualify_dsl.rb --format both --output ~/Desktop --open"

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
          output_pathname = options[:output]

          case format
          when "source"
            write_source(source, source_output_path(flow_file, output_pathname))
          when "image"
            write_image(source, flow_file, output_pathname, options[:open])
          when "both"
            write_source(source, source_output_path(flow_file, output_pathname))
            write_image(
              source,
              flow_file,
              image_output_path(flow_file, output_pathname),
              options[:open]
            )
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
          filename = with_default_extension(output_path, ".mmd")
          File.write(filename, source)
          warn "Diagram written to #{filename}"
        end

        def write_image(source, flow_file, output_path, open_file)
          ensure_mermaid_cli_installed!
          filename = output_path || image_output_path(flow_file, nil)

          Tempfile.create(%w[inquirex-graph .mmd]) do |temp|
            temp.write(source)
            temp.flush
            run_system_command!(
              "mmdc -i #{Shellwords.escape(temp.path)} -o #{Shellwords.escape(filename)}",
              "Failed to generate image (mmdc)"
            )
          end

          warn "Diagram written to #{filename}"
          open_image_file(filename) if open_file
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

        def image_output_path(flow_file, output_path)
          if output_path && File.directory?(output_path)
            return File.join(output_path, "#{flow_basename(flow_file)}.png")
          end
          return with_default_extension(output_path, ".png") if output_path

          "#{flow_basename(flow_file)}.png"
        end

        def source_output_path(flow_file, output_path)
          return nil unless output_path
          if File.directory?(output_path)
            return File.join(output_path, "#{flow_basename(flow_file)}.mmd")
          end

          with_default_extension(output_path, ".mmd")
        end

        def flow_basename(flow_file)
          File.basename(flow_file, File.extname(flow_file))
        end

        def with_extension(path, extension)
          path.sub(%r{\.[^/.]+\z}, extension)
        end

        def with_default_extension(path, extension)
          if File.extname(path) == ""
            "#{path}#{extension}"
          else
            with_extension(path, extension)
          end
        end
      end
    end
  end
end

# rubocop:enable Layout/LineContinuationLeadingSpace
