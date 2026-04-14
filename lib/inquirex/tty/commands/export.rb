# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Exports a flow definition as JSON or YAML (stdout or file).
      #
      # Examples:
      #   inquirex export examples/08_tax_preparer.rb             # JSON to stdout
      #   inquirex export examples/08_tax_preparer.rb -f yml      # YAML to stdout
      #   inquirex export examples/08_tax_preparer.rb -o .        # write 08_tax_preparer.json to cwd
      #   inquirex export examples/08_tax_preparer.rb -f yml -o . # write 08_tax_preparer.yml to cwd
      #   inquirex export examples/08_tax_preparer.rb -o out.json # write to out.json
      class Export < Dry::CLI::Command
        LONG_DESCRIPTION = "Export a flow definition as JSON or YAML.\n\n" \
                           "Example:\n  inquirex export examples/08_tax_preparer.rb -f yml -o ."

        SHORT_DESCRIPTION = "Export a flow definition as JSON or YAML ."

        if ARGV[0] == "export"
          desc LONG_DESCRIPTION
        else
          desc SHORT_DESCRIPTION
        end

        argument :flow_file,
          required: true,
          desc:     "Path to flow definition (.rb file)"
        option :format,
          aliases: ["-f"],
          default: "json",
          values:  %w[json yaml yml],
          desc:    "Output format"
        option :output,
          aliases: ["-o"],
          desc:    "Output file or directory (default: stdout)"

        # @param flow_file [String]
        # @param options [Hash]
        # @return [void]
        def call(flow_file:, **options)
          definition = FlowLoader.load(flow_file)
          format = normalize_format(options[:format])
          content = serialize(definition, format)
          write(content, flow_file, options[:output], extension_for(format))
        rescue Inquirex::TTY::Error => e
          warn "Error: #{e.message}"
          exit 1
        end

        private

        def normalize_format(format)
          %w[yaml yml].include?(format.to_s) ? "yaml" : "json"
        end

        def serialize(definition, format)
          case format
          when "yaml" then definition.to_h.to_yaml
          else             JSON.pretty_generate(definition.to_h)
          end
        end

        def extension_for(format)
          format == "yaml" ? ".yml" : ".json"
        end

        def write(content, flow_file, output, extension)
          path = OutputPath.resolve(flow_file, output, extension)
          unless path
            $stdout.puts content
            return
          end

          File.write(path, content)
          warn "Exported to #{path}"
        end
      end
    end
  end
end
