# frozen_string_literal: true

module Inquirex
  module TTY
    # Renders flow nodes as interactive TTY prompts. Dispatches collecting steps
    # via the node's TTY widget hint (from +Inquirex::WidgetRegistry+ or an
    # explicit +widget target: :tty+ declaration in the DSL).
    #
    # Display verbs render text/boxes and return +nil+; the caller is responsible
    # for calling +engine.advance+.
    #
    # Widget type → tty-prompt method:
    #   text_input     → prompt.ask
    #   multiline      → line-by-line collector (empty line submits)
    #   number_input   → prompt.ask(convert: :int / :float)
    #   currency_input → prompt.ask(convert: :float)
    #   yes_no         → prompt.yes?
    #   select         → prompt.select
    #   multi_select   → prompt.multi_select
    #   enum_select    → prompt.enum_select
    #   mask           → prompt.mask
    #   slider         → prompt.slider
    #   (fallback)     → prompt.ask
    #
    # Header display verb uses TTY::Font for large ASCII-art section titles.
    #
    # {#collect} drives one collecting step against an engine and binds the
    # back key ({BackKey}): pressed in any open prompt, it steps the engine
    # back and the caller's loop re-asks the previous question with its
    # answer as the default.
    class Renderer
      include UIHelper

      # @return [TTY::Prompt]
      attr_reader :prompt

      # @param prompt [TTY::Prompt] injectable for testing
      def initialize(prompt: ::TTY::Prompt.new)
        @prompt = prompt
      end

      # Prints a "thinking" line before the LLM adapter is called.
      # Plain colored text — no animation so it plays nicely with piped output.
      #
      # @param message [String]
      # @return [void]
      def thinking(message)
        sep(:magenta, "─")
        puts pastel.bright_magenta.bold(message)
        sep(:magenta, "─")
      end

      # Prints the structured data extracted by a clarify step, dimming any
      # fields the LLM left blank so the user can see what still needs asking.
      #
      # @param result [Hash] adapter output
      # @return [void]
      def show_extraction(result)
        puts pastel.bold("📋 LLM extracted:")
        result.each do |key, value|
          if value.nil? || (value.respond_to?(:empty?) && value.empty?)
            puts pastel.dim("  ❓ #{key}: (unknown — will ask)")
          else
            puts pastel.green("  ✅ #{key}: #{value.inspect}")
          end
        end
        sep(:magenta, "─")
      end

      # Asks the engine's current collecting step and answers it. When the
      # user presses the back key instead, the engine steps back and nothing
      # is answered; the caller's loop then asks the previous question again,
      # pre-filled with the answer it had.
      #
      # The tip line naming the key appears only when there is somewhere to
      # go back to, and the key is live only then: on the first question it
      # does nothing.
      #
      # @example Drive a flow's collecting steps
      #   until engine.finished?
      #     engine.current_step.display? ? (renderer.render(engine.current_step); engine.advance) : renderer.collect(engine)
      #   end
      #
      # @param engine [Inquirex::Engine] positioned on a collecting step
      # @return [Symbol] +:answered+, or +:back+ when the engine stepped back
      def collect(engine)
        step_id  = engine.current_step_id
        can_back = engine.can_back?
        puts pastel.dim("#{BackKey::LABEL}: back to the previous question") if can_back

        answer = with_back_key(can_back) do
          render(engine.current_step,
            suggestion: engine.suggestion_for(step_id),
            default:    engine.previous_answer(step_id))
        end
        engine.answer(answer)
        :answered
      rescue BackKey::Pressed
        go_back(engine)
        :back
      end

      # Renders a node. Returns the collected answer, or +nil+ for display verbs.
      #
      # @example Collect an answer for the current step, pre-checking LLM suggestions
      #   renderer = Inquirex::TTY::Renderer.new
      #   step   = engine.current_step
      #   answer = renderer.render(step, suggestion: engine.suggestion_for(engine.current_step_id))
      #   engine.answer(answer) unless step.display?
      #
      # @param node [Inquirex::Node]
      # @param suggestion [Array, nil] prefill suggestion for the step (option
      #   form values, e.g. from Engine#suggestion_for) — multi-select prompts
      #   render these choices pre-checked so the user confirms or extends
      # @param default [Object, nil] the answer to pre-fill, e.g. the one the
      #   user gave before going back (Engine#previous_answer)
      # @return [Object, nil]
      def render(node, suggestion: nil, default: nil)
        @current_suggestion = suggestion
        @current_default    = default
        if node.display?
          render_display_verb(node)
          nil
        else
          render_collecting(node)
        end
      ensure
        @current_suggestion = nil
        @current_default    = nil
      end

      private

      # Runs the block with the back key live, when +enabled+.
      #
      # The handler is registered on the prompt's reader once and consulted
      # through @back_armed, so the key raises only inside a collecting
      # prompt: a "Press any key" on a display step treats it as any key.
      #
      # tty-prompt subscribes each question to the reader and unsubscribes it
      # only when the question returns normally. A question unwound by
      # {BackKey::Pressed} would stay subscribed and go on reacting to every
      # later keypress, so the listeners it added are removed here.
      #
      # @param enabled [Boolean]
      # @return [Object] the block's value
      # @raise [BackKey::Pressed] when the key is pressed
      def with_back_key(enabled)
        return yield unless enabled && prompt.respond_to?(:on)

        bind_back_key
        listeners = reader_registrations&.to_a
        @back_armed = true
        yield
      rescue BackKey::Pressed
        drop_listeners_since(listeners)
        raise
      ensure
        @back_armed = false
      end

      # @return [void]
      def bind_back_key
        return if @back_key_bound

        prompt.on(BackKey::EVENT) { |*| raise BackKey::Pressed if @back_armed }
        @back_key_bound = true
      end

      # @param before [Array, nil] the reader's registrations before the prompt opened
      # @return [void]
      def drop_listeners_since(before)
        live = reader_registrations
        return unless before && live

        (live.to_a - before).each { |stale| live.delete(stale) }
      end

      # tty-reader keeps its listeners in Wisper's registration set, which it
      # exposes only privately (its own #unsubscribe reads it the same way).
      #
      # @return [Set, nil]
      def reader_registrations
        reader = prompt.respond_to?(:reader) ? prompt.reader : nil
        return nil unless reader.respond_to?(:local_registrations, true)

        reader.send(:local_registrations)
      end

      # Steps the engine back to the previous question. An LLM step between
      # them is stepped over too: it asks the user nothing, and landing on it
      # would rerun the extraction and carry the user straight forward again.
      #
      # @param engine [Inquirex::Engine]
      # @return [void]
      def go_back(engine)
        engine.back
        engine.back while llm_step?(engine.current_step) && engine.can_back?
        puts pastel.dim("↩ back to #{engine.current_step_id}")
      end

      # @param node [Inquirex::Node, nil]
      # @return [Boolean]
      def llm_step?(node) = node.respond_to?(:llm_verb?) && node.llm_verb?

      # tty-prompt's `default:` option for the value being pre-filled.
      #
      # @param value [Object, nil] defaults to the value passed to #render
      # @return [Hash] {} or { default: value }
      def default_option(value = @current_default)
        value.nil? ? {} : { default: value }
      end

      # select and enum_select preselect by choice NAME, the label the user
      # sees, while answers are option values; translate back.
      #
      # @param node [Inquirex::Node]
      # @return [Hash] {} or { default: label }
      def choice_default(node)
        return {} if @current_default.nil?

        labels = node.respond_to?(:option_labels) ? node.option_labels : nil
        { default: labels&.fetch(@current_default.to_s, nil) || @current_default.to_s }
      end

      # Dispatches display verbs to their styled renderers.
      # :header uses TTY::Font for a large ASCII-art title.
      # :btw and :warning use TTY::Box info/warn boxes.
      # :say outputs plain text.
      # @param node [Inquirex::Node]
      # @return [void]
      def render_display_verb(node)
        case node.verb
        when :header
          render_header(node)
        when :say
          puts "\n#{node.text}\n"
          prompt.keypress(pastel.dim("Press any key to continue..."))
          sep(:green, "━")
        when :btw
          info(node.text)
          prompt.keypress(pastel.dim("Press any key to continue..."))
        when :warning
          warning(node.text)
          prompt.keypress(pastel.dim("Press any key to continue..."))
        else
          puts "\n#{node.text}\n"
          prompt.keypress(pastel.dim("Press any key to continue..."))
        end
      end

      # Renders a header node using TTY::Font for an ASCII-art title.
      # Falls back to a TTY::Box bordered header if font rendering fails
      # (e.g. unsupported characters in the text).
      # @param node [Inquirex::Node]
      # @return [void]
      def render_header(node)
        font = ::TTY::Font.new(:standard)
        title_text = node.text.downcase
        title_text.split.each do |_word|
          title = font.write(node.text.upcase)
          puts pastel.yellow(title)
        end
        sep(:cyan, "━")
        prompt.keypress(pastel.dim("Press any key to continue..."))
      rescue StandardError
        # Fall back to tty-box if TTY::Font cannot render the text
        puts box(node.text, bg: :blue, fg: :white)
        prompt.keypress(pastel.dim("Press any key to continue..."))
        sep(:cyan, "━")
      end

      # Gets the effective TTY widget hint and dispatches to the right render method.
      # @param node [Inquirex::Node]
      # @return [Object]
      def render_collecting(node)
        hint = effective_tty_hint(node)
        method_name = :"render_#{hint.type}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          render_text_input(node)
        end
      end

      # Returns the effective TTY widget hint for a node, with a text_input fallback.
      # @param node [Inquirex::Node]
      # @return [Inquirex::WidgetHint]
      def effective_tty_hint(node)
        hint =
          if node.respond_to?(:effective_widget_hint_for)
            node.effective_widget_hint_for(target: :tty)
          else
            Inquirex::WidgetRegistry.default_hint_for(node.type, context: :tty)
          end
        hint || Inquirex::WidgetHint.new(type: :text_input)
      end

      # Single-line text.
      def render_text_input(node)
        prompt.ask(node.question, **default_option)
      end

      # Multi-line text (empty line to submit).
      def render_multiline(node)
        puts pastel.bold(node.question)
        puts pastel.dim("Enter your response. Press Enter on a blank line to submit.")
        puts pastel.dim("Previous answer:\n#{@current_default}") unless @current_default.nil?
        sep(:cyan, "─")
        collect_multiline_text
      end

      def collect_multiline_text
        lines = []
        loop do
          line = prompt.ask(">") { |q| q.required(false) }
          break if line.nil? || line.empty?

          lines << line
        end
        sep(:cyan, "─")
        lines.empty? ? nil : lines.join("\n")
      end

      # Integer or float depending on the node's data type.
      def render_number_input(node)
        convert = node.type == :integer ? :int : :float
        ask_bounded(node, convert:)
      end

      # Float for currency types.
      def render_currency_input(node)
        ask_bounded(node, convert: :float)
      end

      # Asks for a number, enforcing the node's declared bounds.
      #
      # tty-prompt's `in:` re-asks until the answer falls inside the range,
      # which is the terminal's equivalent of the widget's stepper bounds — the
      # user is corrected before the value is ever stored, rather than having it
      # silently clamped afterwards. An unbounded node keeps the plain ask so
      # the prompt text is unchanged for the overwhelmingly common case.
      #
      # @param node [Inquirex::Node] the step being rendered
      # @param convert [Symbol] :int or :float
      # @return [Numeric, nil]
      def ask_bounded(node, convert:)
        return prompt.ask(node.question, convert:, **default_option) unless node.bounded?

        prompt.ask(node.question, convert:, in: bounds_range(node), **default_option) do |q|
          q.messages[:range?] = "Enter a value #{describe_bounds(node)}."
        end
      end

      # The node's bounds as a Range tty-prompt understands. An open end is
      # spelled with infinity rather than omitted, since `in:` wants a Range.
      #
      # @param node [Inquirex::Node]
      # @return [Range]
      def bounds_range(node)
        low  = node.min || -Float::INFINITY
        high = node.max || Float::INFINITY
        low..high
      end

      # @param node [Inquirex::Node]
      # @return [String] human phrasing of whichever bounds exist
      def describe_bounds(node)
        return "between #{node.min} and #{node.max}" if node.min && node.max
        return "of #{node.min} or more" if node.min

        "of #{node.max} or less"
      end

      # Boolean — tty-prompt yes?.
      def render_yes_no(node)
        prompt.yes?(node.question, **default_option)
      end

      # Single-choice scrollable menu.
      def render_select(node)
        prompt.select(node.question, select_options(node), **choice_default(node))
      end

      # Multiple-choice list (space to toggle, min 1 selection). Suggested
      # choices (an LLM extraction the user should confirm) render pre-checked,
      # and after going back, the choices the user had made.
      def render_multi_select(node)
        prompt.multi_select(node.question, select_options(node), min: 1, **multi_select_defaults(node))
      end

      # tty-prompt pre-checks multi_select choices via default: choice NAMES —
      # the labels, not the return values. Suggestions arrive as option form
      # values (that is the wire contract), so translate value → label here;
      # a value with no label entry falls back to itself.
      #
      # @param node [Inquirex::Node]
      # @return [Hash] {} or { default: Array<String> }
      def multi_select_defaults(node)
        suggested = Array(@current_default.nil? ? @current_suggestion : @current_default)
        return {} if suggested.empty?

        labels = node.respond_to?(:option_labels) ? node.option_labels : nil
        names = suggested.map { |value| labels&.fetch(value.to_s, nil) || value.to_s }
        { default: names }
      end

      # Numbered choice menu.
      def render_enum_select(node)
        prompt.enum_select(node.question, select_options(node), **choice_default(node))
      end

      # Hidden / masked input.
      def render_mask(node)
        prompt.mask(node.question)
      end

      # Numeric slider. Reads min/max/step from explicit widget hint options.
      def render_slider(node)
        opts = {}
        if node.respond_to?(:effective_widget_hint_for)
          hint_opts = node.effective_widget_hint_for(target: :tty)&.options || {}
          opts[:min]  = hint_opts[:min]  if hint_opts[:min]
          opts[:max]  = hint_opts[:max]  if hint_opts[:max]
          opts[:step] = hint_opts[:step] if hint_opts[:step]
        end
        prompt.slider(node.question, **opts, **default_option)
      end

      # Aliases: date, email, phone degrade to plain text_input in TTY.
      alias render_date_picker  render_text_input
      alias render_email_input  render_text_input
      alias render_phone_input  render_text_input
      # textarea is multiline in TTY
      alias render_textarea     render_multiline

      # Returns options suitable for TTY::Prompt select/multi_select.
      # Inquirex exposes option values via `node.options` and display labels
      # via `node.option_labels` ({value => label}). TTY::Prompt expects a
      # Hash in the opposite orientation: {label => return_value}.
      def select_options(node)
        values = node.options || []
        labels = node.respond_to?(:option_labels) ? node.option_labels : nil
        return values unless labels && !labels.empty?

        values.to_h { |v| [labels[v] || v, v] }
      end
    end
  end
end
