# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Exports a flow definition as a Mermaid flowchart (stdout or file).
      class Graph < Dry::CLI::Command
        desc "Export a flow definition as a Mermaid diagram"

        argument :flow_file, required: true, desc: "Path to flow definition (.rb file)"
        option :output, aliases: ["-o"], desc: "Output file (default: stdout)"
        option :format,
          aliases: ["-f"],
          default: "source",
          values:  %w[source image],
          desc:    "Output format: source (Mermaid text) or image (SVG via mmdc)"
        option :open,
          aliases: ["-p"],
          default: false,
          type:    :boolean,
          desc:    "Open the image in the system viewer after generating (requires --format image)"

        # @param flow_file [String]
        # @param options [Hash]
        # @return [void]
        def call(flow_file:, **options)
          definition = FlowLoader.load(flow_file)
          source     = Inquirex::Graph::MermaidExporter.new(definition).export

          if options[:format] == "image"
            write_image(source, flow_file, options[:output], options[:open])
          else
            write_source(source, options[:output])
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
          filename = with_extension(output_path, ".mmd")
          File.write(filename, source)
          warn "Diagram written to #{filename}"
        end

        def write_image(source, flow_file, output_path, open_file)
          ensure_mermaid_cli_installed!
          filename = image_output_path(flow_file, output_path)

          Tempfile.create(["inquirex-graph", ".mmd"]) do |temp|
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
          run_system_command!("open #{Shellwords.escape(filename)}", "Failed to open #{filename}")
        end

        def command_available?(command)
          system("command -v #{command} > /dev/null 2>&1")
        end

        def run_system_command!(command, error_message)
          raise Inquirex::TTY::Error, error_message unless system(command)
        end

        def image_output_path(flow_file, output_path)
          return with_default_extension(output_path, ".svg") if output_path

          "#{File.basename(flow_file, ".rb")}.svg"
        end

        def with_extension(path, extension)
          path.sub(%r{\.[^/.]+\z}, extension)
        end

        def with_default_extension(path, extension)
          File.extname(path) == "" ? "#{path}#{extension}" : path
        end
      end
    end
  end
end
