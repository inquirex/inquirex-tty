# frozen_string_literal: true

module Inquirex
  module TTY
    # Raised out of a tty-prompt widget when the user presses a navigation key.
    # The run loop rescues it and acts on {#action}; the widget is abandoned
    # mid-read, which tty-prompt tolerates (its widgets restore the cursor in
    # +ensure+ and the reader leaves raw mode in its own block).
    class Navigation < StandardError
      # @return [Symbol] :back, :skip or :help
      attr_reader :action

      # @param action [Symbol] :back, :skip or :help
      def initialize(action)
        @action = action
        super("navigation: #{action}")
      end
    end

    # A tty-reader listener that turns navigation keys into {Navigation}
    # exceptions while a widget is reading input.
    #
    # Backspace and "?" are also ordinary editing keys, so they navigate only
    # when the answer being typed is empty: Backspace on an empty line goes
    # back, Backspace with text deletes a character. Lists, sliders and
    # "press any key" prompts have no text, so there they always navigate.
    #
    # tty-reader reports a key after it has edited the line, so the listener
    # cannot ask "was the line empty?" directly. It keeps its own count of the
    # characters typed instead, from how much each event's line grew or shrank.
    #
    # @example Wrap a prompt call
    #   prompt.subscribe(KeyMap.new(prefilled: "Alan")) { prompt.ask("Name?", value: "Alan") }
    class KeyMap
      # Key names (from tty-reader) that request going back.
      BACK_KEYS = %i[backspace ctrl_h].freeze

      # Every navigation key, for the hint line and the help box.
      BINDINGS = [
        ["Enter",            "submit the answer"],
        ["Backspace",        "go back to the previous question (on an empty answer)"],
        ["Ctrl-S",           "skip the question (optional questions only)"],
        ["↑ ↓  Space",       "move and toggle in a list"],
        ["?",                "show this help (on an empty answer)"],
        ["Ctrl-C",           "abort without saving"]
      ].freeze

      # The one-line reminder rendered next to each widget.
      HINT = "⌫ back · ^S skip · ? keys · ^C abort"

      # @param prefilled [String] text the line starts with (a pre-filled answer)
      def initialize(prefilled: "")
        @length = prefilled.to_s.length
        @line   = nil
      end

      # tty-reader calls this for every key, after any key-specific handler.
      #
      # @param event [TTY::Reader::KeyEvent]
      # @return [void]
      # @raise [Navigation] when the key is a navigation key
      def keypress(event)
        name = event.key.name
        raise Navigation, :skip if name == :ctrl_s
        raise Navigation, :back if BACK_KEYS.include?(name) && @length.zero?
        raise Navigation, :help if event.value == "?" && @length.zero?

        track(event)
      end

      private

      # Updates the typed-character count after an editing key.
      #
      # A line widget passes its whole line (prompt plus text) with each event;
      # list widgets pass an empty string, and the only text they hold is the
      # number typed into an enum_select.
      #
      # @param event [TTY::Reader::KeyEvent]
      # @return [void]
      def track(event)
        return reset if %i[return enter].include?(event.key.name)
        return track_keys(event) if event.line.to_s.empty?

        delta = @line ? event.line.length - @line.length : first_delta(event)
        @length = [@length + delta, 0].max
        @line = event.line
      end

      # The first event of a line has nothing to diff against, so its effect is
      # inferred from the key: the cursor starts at the end of the line.
      def first_delta(event)
        return -1 if BACK_KEYS.include?(event.key.name)

        printable?(event.value) ? 1 : 0
      end

      def track_keys(event)
        if BACK_KEYS.include?(event.key.name) || event.key.name == :delete
          @length = [@length - 1, 0].max
        elsif event.key.name == :num
          @length += event.value.length
        end
      end

      # Enter submits; a widget that reads several lines (multiline text)
      # starts the next one empty.
      def reset
        @length = 0
        @line = nil
      end

      def printable?(value)
        value.to_s.length == 1 && value.match?(/[[:print:]]/)
      end
    end
  end
end
