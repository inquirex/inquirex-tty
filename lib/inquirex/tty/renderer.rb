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
      # @return [Object, nil]
      def render(node, suggestion: nil)
        @current_suggestion = suggestion
        if node.display?
          render_display_verb(node)
          nil
        else
          render_collecting(node)
        end
      ensure
        @current_suggestion = nil
      end

      private

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
        prompt.ask(node.question)
      end

      # Multi-line text (empty line to submit).
      def render_multiline(node)
        puts pastel.bold(node.question)
        puts pastel.dim("Enter your response. Press Enter on a blank line to submit.")
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
        return prompt.ask(node.question, convert:) unless node.bounded?

        prompt.ask(node.question, convert:, in: bounds_range(node)) do |q|
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
        prompt.yes?(node.question)
      end

      # Single-choice scrollable menu.
      def render_select(node)
        prompt.select(node.question, select_options(node))
      end

      # Multiple-choice list (space to toggle, min 1 selection). Suggested
      # choices (an LLM extraction the user should confirm) render pre-checked.
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
        suggested = Array(@current_suggestion)
        return {} if suggested.empty?

        labels = node.respond_to?(:option_labels) ? node.option_labels : nil
        names = suggested.map { |value| labels&.fetch(value.to_s, nil) || value.to_s }
        { default: names }
      end

      # Numbered choice menu.
      def render_enum_select(node)
        prompt.enum_select(node.question, select_options(node))
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
        prompt.slider(node.question, **opts)
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
