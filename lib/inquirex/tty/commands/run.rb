# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Runs a flow definition and writes the collected answers (plus
      # metadata) as JSON to stdout, or to the file named by -o.
      #
      # Interactively, every prompt, box and progress line goes to stderr, so
      # stdout carries the results and nothing else: `inquirex-tty run flow.rb
      # > answers.json` captures a clean document. With --answers or --yes the
      # run is headless: Inquirex::Headless feeds the engine, and no prompt,
      # renderer or LLM adapter is ever built, so it needs no TTY.
      class Run < Dry::CLI::Command
        desc "Run a flow definition interactively, or headless from an answers file"

        argument :flow_file, required: true, desc: "Path to flow definition (.rb file)"
        option :answers, desc: "Run headless with these answers ({step_id: value}, .json, .yml or .yaml)"
        option :yes,
          type:    :boolean,
          default: false,
          aliases: ["-y"],
          desc:    "Run headless, taking each unanswered step's default"
        option :output, aliases: ["-o"], desc: "Write JSON results to this file (- for stdout, the default)"

        # @param flow_file [String]
        # @param options [Hash] :answers, :yes, :output
        # @return [void]
        def call(flow_file:, **options)
          json = on_stderr { JSON.pretty_generate(results_for(flow_file, **options)) }
          write_results(json, options[:output])
        rescue Inquirex::TTY::Error => e
          on_stderr { error(e.message) }
          exit 1
        rescue Inquirex::Errors::Error => e
          on_stderr { error("Engine error: #{e.message}") }
          exit 1
        end

        private

        # @param flow_file [String]
        # @param answers [String, nil] answers file path
        # @param yes [Boolean]
        # @return [Hash]
        def results_for(flow_file, answers: nil, yes: false, **)
          if answers || yes
            build_result(flow_file, run_headless(flow_file, answers, yes))
          else
            engine = run_flow(flow_file)
            build_result(flow_file,
              path_taken:      engine.history,
              answers:         engine.answers_with_metadata,
              steps_completed: engine.history.length)
          end
        end

        # Points $stdout at stderr for the block, so every `puts` and every
        # TTY::Prompt built inside it (its output defaults to $stdout when it
        # is created) write to stderr.
        #
        # @return [Object] the block's value
        def on_stderr
          original = $stdout
          $stdout = $stderr
          yield
        ensure
          $stdout = original
        end

        # @param json [String]
        # @param output [String, nil] a path, "-" or nil for stdout
        # @return [void]
        def write_results(json, output)
          if output.nil? || output == "-"
            $stdout.puts json
          else
            File.write(output, "#{json}\n")
            warn "Results saved to #{output}"
          end
        end

        # Runs the flow with no TTY. Completion metadata is gathered without
        # the public-IP probe: a headless run is for tests and CI, and should
        # neither wait on nor reach the network.
        #
        # @param flow_file [String]
        # @param answers_file [String, nil]
        # @param yes [Boolean]
        # @return [Hash] Inquirex::Headless#call results
        def run_headless(flow_file, answers_file, yes)
          answers  = answers_file ? AnswersFile.load(answers_file) : {}
          headless = Inquirex::Headless.new(FlowLoader.load(flow_file), answers:, yes:)
          headless.engine.after_completion { |eng| eng.completion_metadata = build_completion_metadata(network: false) }
          headless.call
        end

        # @param flow_file [String]
        # @return [Inquirex::Engine]
        def run_flow(flow_file)
          load_dotenv!
          definition = FlowLoader.load(flow_file)
          engine     = Inquirex::Engine.new(definition)
          renderer   = Renderer.new
          adapter    = build_llm_adapter

          engine.after_completion { |eng| eng.completion_metadata = build_completion_metadata }

          show_banner(definition)

          until engine.finished?
            step = engine.current_step
            # history already ends with the current step, so its length is
            # the step's number; adding one printed "Step 2" for the first.
            next_step(engine.current_step_id, engine.history.length)

            if step.respond_to?(:llm_verb?) && step.llm_verb?
              run_llm_step(engine, step, adapter, renderer)
            elsif step.display?
              renderer.render(step)
              engine.advance
            else
              renderer.collect(engine)
            end
          end

          engine
        end

        # Calls the LLM adapter for an LLM step, stores the result as the step's
        # answer, and for extract verbs splats the extracted fields into top-level
        # answers via Engine#prefill! so that downstream `skip_if not_empty(:key)`
        # rules will fire. `clarify` is a DSL alias for `extract`, so a node built
        # by either verb reports :extract.
        def run_llm_step(engine, step, adapter, renderer)
          renderer.thinking("🧠 Thinking — asking #{adapter_label(adapter)} to extract structured data…")
          result = adapter.call(step, engine.answers)
          engine.answer(result)
          if step.verb == :extract && result.is_a?(Hash)
            engine.prefill!(result)
            renderer.show_extraction(result)
          else
            puts "\n#{result.is_a?(String) ? result : JSON.pretty_generate(result)}\n"
          end
        rescue StandardError => e
          error("LLM step #{step.id} failed: #{e.class}: #{e.message}")
          raise
        end

        # The adapter inquirex-llm's configuration selects (first match wins):
        #   INQUIREX_LLM_ADAPTER=null         → NullAdapter (forced offline)
        #   INQUIREX_LLM_ADAPTER=anthropic    → AnthropicAdapter (fails if no key)
        #   INQUIREX_LLM_ADAPTER=openai       → OpenAIAdapter (fails if no key)
        #   ANTHROPIC_API_KEY present         → AnthropicAdapter
        #   OPENAI_API_KEY present            → OpenAIAdapter
        #   otherwise                         → NullAdapter
        #
        # The configuration reads ENV once, and load_dotenv! has just added
        # to it, so it is rebuilt first; a key that lives only in .env would
        # otherwise be missed.
        #
        # @return [Inquirex::LLM::Adapter]
        def build_llm_adapter
          Inquirex::LLM.reset_configuration!
          Inquirex::LLM.adapter
        end

        def adapter_label(adapter)
          case adapter
          when Inquirex::LLM::AnthropicAdapter then "Claude"
          when Inquirex::LLM::OpenAIAdapter    then "GPT"
          else "the null adapter"
          end
        rescue NameError
          "the null adapter"
        end

        # Minimal .env loader. Walks up from the cwd and the flow file's
        # directory, loading every .env found along the way. Later loads do
        # not overwrite earlier values, and nothing overrides keys already
        # set in the real environment.
        def load_dotenv!
          seen = {}
          [Dir.pwd, File.dirname(File.expand_path(ARGV.last.to_s))].uniq.each do |start|
            walk_ancestors(start).each do |dir|
              path = File.join(dir, ".env")
              next if seen[path] || !File.file?(path)

              seen[path] = true
              load_env_file(path)
            end
          end
        end

        def walk_ancestors(dir)
          ancestors = []
          current = File.expand_path(dir)
          loop do
            ancestors << current
            parent = File.dirname(current)
            break if parent == current

            current = parent
          end
          ancestors
        end

        def load_env_file(path)
          File.foreach(path) do |line|
            next if line.strip.empty? || line.start_with?("#")

            key, _, value = line.strip.partition("=")
            next if key.empty?
            # Preserve shell-set values, but fill in keys that are unset or
            # set to the empty string.
            next if ENV.key?(key) && !ENV[key].to_s.empty?

            ENV[key] = value.gsub(/\A["']|["']\z/, "")
          end
        end

        # @param definition [Inquirex::Definition]
        # @return [void]
        def show_banner(definition)
          title = definition.meta&.fetch(:title, nil) || "Inquirex"
          font  = ::TTY::Font.new(:standard)
          title.split.each do |word|
            puts pastel.bright_yellow(font.write(word))
          end
          sep(:green, "❚")
        rescue StandardError
          puts box(definition.meta&.fetch(:title, nil) || "Inquirex Wizard")
        end

        # @param flow_file [String]
        # @param run [Hash] :path_taken, :answers, :steps_completed
        # @return [Hash]
        def build_result(flow_file, run)
          { flow_file: flow_file, **run.slice(:path_taken, :answers, :steps_completed), completed_at: Time.now.iso8601 }
        end

        # Rich completion metadata for the answers. Only :engine and
        # :engine_version are guaranteed — the environment probes are
        # best-effort: a failing one (offline host, no login name, blocked
        # egress) yields nil and its member is dropped.
        #
        # @param network [Boolean] whether to ask a remote service for the public IP
        # @return [Inquirex::CompletionMetadata]
        def build_completion_metadata(network: true)
          optional = {
            uname:     best_effort { OpenStruct.new(Etc.uname) },
            user:      best_effort { Etc.getlogin },
            local_ip:  best_effort { local_ip },
            public_ip: network ? best_effort { public_ip } : nil,
            terminal:  ENV["LC_TERMINAL"] || ENV["TERM_PROGRAM"] || "Unknown"
          }.compact
          Inquirex::CompletionMetadata.new(
            engine:         "inquirex-tty",
            engine_version: Inquirex::TTY::VERSION,
            **optional
          )
        end

        def best_effort
          yield
        rescue StandardError
          nil
        end

        # The local address the OS would route out through — a UDP "connect"
        # picks the outbound interface without sending a single packet.
        def local_ip
          UDPSocket.open do |socket|
            socket.connect("8.8.8.8", 1)
            socket.addr.last
          end
        end

        # Short timeouts so a slow or airgapped network can never stall the
        # CLI at completion time.
        def public_ip
          Net::HTTP.start("api.ipify.org", 443, use_ssl: true, open_timeout: 2, read_timeout: 2) do |http|
            response = http.get("/")
            response.is_a?(Net::HTTPSuccess) ? response.body.to_s.strip : nil
          end
        end
      end
    end
  end
end
