# frozen_string_literal: true

require "gtk4"

module Sudoku
  # Ported from upstream src/shared/input_handler.py.
  #
  # Translates raw GTK key and gesture events into game actions. Every action
  # is injected at construction, so this class knows nothing about the board,
  # the grid or the window.
  class InputHandler
    ARROW_STEP = 1
    BLOCK_STEP = 3

    KEY_MAP = (1..9).each_with_object({}) do |number, map|
      map[Gdk::Keyval.const_get("KEY_#{number}")] = number.to_s
      map[Gdk::Keyval.const_get("KEY_KP_#{number}")] = number.to_s
    end.freeze

    REMOVE_KEYS = [
      Gdk::Keyval::KEY_BackSpace,
      Gdk::Keyval::KEY_Delete,
      Gdk::Keyval::KEY_KP_Delete,
    ].freeze

    ENTER_KEYS = [Gdk::Keyval::KEY_Return, Gdk::Keyval::KEY_KP_Enter].freeze

    # The codepoints that start a run of ten decimal digits, so a key typed on
    # a Persian or Arabic keyboard fills the same cell an ASCII digit would.
    # Upstream reaches for unicodedata.digit; Ruby has no numeric-value lookup,
    # so the scripts the game is translated into are listed instead.
    DIGIT_ZEROS = [
      0x0030, # ASCII
      0x0660, # Arabic-Indic
      0x06F0, # Extended Arabic-Indic (Persian)
      0x0966, # Devanagari
      0x09E6, # Bengali
      0x0E50, # Thai
      0xFF10, # Fullwidth
    ].freeze

    attr_reader :handle_fill, :handle_clear

    def initialize(
      on_move:,
      on_fill:,
      on_clear:,
      on_show_popover:,
      on_cell_click:,
      board_size:,
      direction:
    )
      @on_move = on_move
      @handle_fill = on_fill
      @handle_clear = on_clear
      @on_show_popover = on_show_popover
      @on_cell_click = on_cell_click
      @board_size = board_size
      @direction = direction
    end

    # A click gesture for one cell. The caller adds it to the cell widget.
    def make_cell_gesture(row, col)
      Gtk::GestureClick.new.tap do |gesture|
        gesture.button = 0
        gesture.propagation_phase = :capture
        gesture.signal_connect("released") do |released, n_press, _x, _y|
          on_cell_clicked(
            released,
            n_press,
            row,
            col,
          )
        end
      end
    end

    def make_cell_key_controller(row, col)
      Gtk::EventControllerKey.new.tap do |controller|
        controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, state|
          on_key_pressed(
            keyval,
            state,
            row,
            col,
          )
        end
      end
    end

    # A key controller for the number popover: digits press the matching
    # number button, Delete and Backspace press Clear.
    def make_popover_key_controller(num_buttons, clear_button)
      Gtk::EventControllerKey.new.tap do |controller|
        controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, _state|
          popover_key_pressed(keyval, num_buttons, clear_button)
        end
      end
    end

    def on_key_pressed(keyval, state, row, col)
      ctrl = state.to_i.anybits?(Gdk::ModifierType::CONTROL_MASK.to_i)

      handle_arrow_keys(
        keyval,
        ctrl,
        row,
        col,
      ) ||
        handle_number_keys(
          keyval,
          ctrl,
          row,
          col,
        ) ||
        handle_unicode_digit(
          keyval,
          ctrl,
          row,
          col,
        ) ||
        handle_enter_key(keyval, row, col) ||
        handle_remove_keys(keyval, row, col)
    end

    def on_cell_clicked(gesture, n_press, row, col)
      button = gesture.current_button
      state = gesture.current_event_state.to_i
      if [1, 3].include?(button) && !ghost_click?(button, state)
        @on_cell_click.call(
          row,
          col,
          button,
          n_press,
        )
      end
    end

    # One mouse button held while the other fires sends a release for a press
    # the player never meant; those are dropped.
    def ghost_click?(button, state)
      held_right = button == 1 && state.anybits?(Gdk::ModifierType::BUTTON3_MASK.to_i)
      held_left = button == 3 && state.anybits?(Gdk::ModifierType::BUTTON1_MASK.to_i)
      held_right || held_left
    end

    private

      def popover_key_pressed(keyval, num_buttons, clear_button)
        number = KEY_MAP[keyval]
        pressed = false
        if number && num_buttons.key?(number)
          num_buttons[number].signal_emit("clicked")
          pressed = true
        end
        if !pressed && REMOVE_KEYS.include?(keyval)
          clear_button.signal_emit("clicked")
          pressed = true
        end
        pressed
      end

      # Arrow keys move the focus one cell, or one block with Ctrl held. Left
      # and right swap over in a right-to-left layout.
      def handle_arrow_keys(keyval, ctrl, row, col)
        step = directions[keyval]
        if step
          if ctrl
            multiplier = BLOCK_STEP
          else
            multiplier = ARROW_STEP
          end
          move_focus(
            row,
            col,
            step[0] * multiplier,
            step[1] * multiplier,
          )
          true
        else
          false
        end
      end

      def directions
        if rtl?
          horizontal = -ARROW_STEP
        else
          horizontal = ARROW_STEP
        end
        {
          Gdk::Keyval::KEY_Up    => [-ARROW_STEP, 0],
          Gdk::Keyval::KEY_Down  => [ARROW_STEP, 0],
          Gdk::Keyval::KEY_Left  => [0, -horizontal],
          Gdk::Keyval::KEY_Right => [0, horizontal],
        }
      end

      def move_focus(row, col, delta_row, delta_col)
        size = @board_size.call
        new_row = row + delta_row
        new_col = col + delta_col
        if (0...size).cover?(new_row) && (0...size).cover?(new_col)
          @on_move.call(
            row,
            col,
            new_row,
            new_col,
          )
        end
      end

      def rtl? = @direction.call == Gtk::TextDirection::RTL

      def handle_number_keys(keyval, ctrl, row, col)
        number = KEY_MAP[keyval]
        if number
          @handle_fill.call(
            row,
            col,
            number,
            ctrl,
          )
          true
        else
          false
        end
      end

      def handle_unicode_digit(keyval, ctrl, row, col)
        digit = unicode_digit(Gdk::Keyval.to_unicode(keyval))
        if digit
          @handle_fill.call(
            row,
            col,
            digit.to_s,
            ctrl,
          )
          true
        else
          false
        end
      end

      def unicode_digit(codepoint)
        if codepoint.positive?
          DIGIT_ZEROS.map { |zero| codepoint - zero }.find { |digit| (1..9).cover?(digit) }
        end
      end

      def handle_enter_key(keyval, row, col)
        if ENTER_KEYS.include?(keyval)
          @on_show_popover.call(row, col, 0)
          true
        else
          false
        end
      end

      def handle_remove_keys(keyval, row, col)
        if REMOVE_KEYS.include?(keyval)
          @handle_clear.call(row, col, keyval == Gdk::Keyval::KEY_Delete)
          true
        else
          false
        end
      end
  end
end
