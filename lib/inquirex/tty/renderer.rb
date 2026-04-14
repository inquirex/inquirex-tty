# frozen_string_literal: true

module Inquirex
  module TTY
    # Renders flow nodes as interactive TTY prompts. Dispatches collecting steps
    # via the node's TTY widget hint (from +Inquirex::UI::WidgetRegistry+ or an
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

      # Renders a node. Returns the collected answer, or +nil+ for display verbs.
      # @param node [Inquirex::Node, Inquirex::UI::Node]
      # @return [Object, nil]
      def render(node)
        if node.display?
          render_display_verb(node)
          nil
        else
          render_collecting(node)
        end
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
        font  = ::TTY::Font.new(:standard)
        title = font.write(node.text.upcase)
        puts pastel.bright_cyan(title)
        sep(:cyan, "━")
        prompt.keypress(pastel.dim("Press any key to continue..."))
      rescue StandardError
        # Fall back to tty-box if TTY::Font cannot render the text
        puts box(node.text, bg: :blue, fg: :white)
        prompt.keypress(pastel.dim("Press any key to continue..."))
        sep(:cyan, "━")
      end

      # Gets the effective TTY widget hint and dispatches to the right render method.
      # @param node [Inquirex::UI::Node, Inquirex::Node]
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
      # @param node [Inquirex::UI::Node, Inquirex::Node]
      # @return [Inquirex::UI::WidgetHint]
      def effective_tty_hint(node)
        hint =
          if node.respond_to?(:effective_widget_hint_for)
            node.effective_widget_hint_for(target: :tty)
          else
            Inquirex::UI::WidgetRegistry.default_hint_for(node.type, context: :tty)
          end
        hint || Inquirex::UI::WidgetHint.new(type: :text_input)
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
        prompt.ask(node.question, convert:)
      end

      # Float for currency types.
      def render_currency_input(node)
        prompt.ask(node.question, convert: :float)
      end

      # Boolean — tty-prompt yes?.
      def render_yes_no(node)
        prompt.yes?(node.question)
      end

      # Single-choice scrollable menu.
      def render_select(node)
        prompt.select(node.question, select_options(node))
      end

      # Multiple-choice list (space to toggle, min 1 selection).
      def render_multi_select(node)
        prompt.multi_select(node.question, select_options(node), min: 1)
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
      # Inquirex options: Array<String> or Hash{ value => label }.
      # TTY::Prompt accepts both (Hash key=return value, value=display label).
      def select_options(node)
        node.options || []
      end
    end
  end
end
