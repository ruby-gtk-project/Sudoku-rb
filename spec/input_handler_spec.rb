# frozen_string_literal: true

# Ported from upstream tests/test_input_handler.py.
#
# Upstream's handler takes a `get_board_size` and `get_direction` callable and
# exposes public `handle_fill(row, col, value, ctrl)` / `handle_clear(row,
# col, clear_all:)` methods that delegate to injected callbacks. The port's
# constructor keyword is `board_size:`/`direction:` (still callables) and
# `handle_fill`/`handle_clear` are `attr_reader`s exposing the injected
# callback itself, invoked internally by `#on_key_pressed` — so the "delegates
# to callback" cases below call `#on_key_pressed` instead of a public
# `handle_fill`/`handle_clear` method, which does not exist in the port.

RSpec.describe Sudoku::InputHandler do
  def make_handler(**overrides)
    defaults = {
      on_move:         ->(*) {},
      on_fill:         ->(*) {},
      on_clear:        ->(*) {},
      on_show_popover: ->(*) {},
      on_cell_click:   ->(*) {},
      board_size:      -> { 9 },
      direction:       -> { Gtk::TextDirection::LTR },
    }
    described_class.new(**defaults.merge(overrides))
  end

  # Ported from TestKeyMappings.
  describe "key mappings" do
    it "test_digit_keys_mapped" do
      (1..9).each do |i|
        keyval = Gdk::Keyval.const_get("KEY_#{i}")
        expect(described_class::KEY_MAP[keyval]).to eq(i.to_s)
      end
    end

    it "test_numpad_keys_mapped" do
      (1..9).each do |i|
        keyval = Gdk::Keyval.const_get("KEY_KP_#{i}")
        expect(described_class::KEY_MAP[keyval]).to eq(i.to_s)
      end
    end

    it "test_remove_keys_include_backspace_and_delete" do
      expect(described_class::REMOVE_KEYS).to include(Gdk::Keyval::KEY_BackSpace)
      expect(described_class::REMOVE_KEYS).to include(Gdk::Keyval::KEY_Delete)
      expect(described_class::REMOVE_KEYS).to include(Gdk::Keyval::KEY_KP_Delete)
    end
  end

  # Ported from TestPublicAPI, adapted: `handle_fill`/`handle_clear` are the
  # raw injected callbacks, not wrapper methods.
  describe "public callback accessors" do
    it "test_handle_fill_is_public" do
      on_fill = ->(*) {}
      h = make_handler(on_fill: on_fill)
      expect(h.handle_fill).to be(on_fill)
    end

    it "test_handle_clear_is_public" do
      on_clear = ->(*) {}
      h = make_handler(on_clear: on_clear)
      expect(h.handle_clear).to be(on_clear)
    end

    it "test_handle_fill_delegates_to_callback" do
      calls = []
      on_fill = ->(*args) { calls << args }
      h = make_handler(on_fill: on_fill)
      h.on_key_pressed(
        Gdk::Keyval::KEY_5,
        0,
        2,
        3,
      )
      expect(calls).to eq([[2, 3, "5", false]])
    end

    it "test_handle_clear_delegates_to_callback" do
      calls = []
      on_clear = ->(*args) { calls << args }
      h = make_handler(on_clear: on_clear)
      h.on_key_pressed(
        Gdk::Keyval::KEY_Delete,
        0,
        2,
        3,
      )
      expect(calls).to eq([[2, 3, true]])
    end
  end

  # Ported from TestArrowNavigation.
  describe "arrow navigation" do
    it "test_arrow_down" do
      calls = []
      h = make_handler(on_move: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_Down,
        0,
        3,
        3,
      )
      expect(calls).to eq([[3, 3, 4, 3]])
    end

    it "test_arrow_up" do
      calls = []
      h = make_handler(on_move: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_Up,
        0,
        3,
        3,
      )
      expect(calls).to eq([[3, 3, 2, 3]])
    end

    it "test_arrow_right" do
      calls = []
      h = make_handler(on_move: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_Right,
        0,
        3,
        3,
      )
      expect(calls).to eq([[3, 3, 3, 4]])
    end

    it "test_ctrl_right_jumps_by_block" do
      calls = []
      h = make_handler(on_move: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_Right,
        Gdk::ModifierType::CONTROL_MASK,
        3,
        3,
      )
      expect(calls).to eq([[3, 3, 3, 6]])
    end

    it "test_arrow_blocked_at_boundary" do
      calls = []
      h = make_handler(on_move: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_Up,
        0,
        0,
        0,
      )
      expect(calls).to eq([])
    end
  end

  # Ported from TestNumberKeys.
  describe "number keys" do
    it "test_digit_key_fills" do
      calls = []
      h = make_handler(on_fill: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_5,
        0,
        2,
        3,
      )
      expect(calls).to eq([[2, 3, "5", false]])
    end

    it "test_ctrl_digit_fills_with_ctrl" do
      calls = []
      h = make_handler(on_fill: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_5,
        Gdk::ModifierType::CONTROL_MASK,
        2,
        3,
      )
      expect(calls).to eq([[2, 3, "5", true]])
    end
  end

  # Ported from TestUnicodeDigits, adapted: the port's unicode-digit handler
  # is private, reached only through `#on_key_pressed`'s dispatch chain. A
  # non-digit, non-mapped key falls through every handler and fires nothing.
  describe "non-digit keys" do
    it "test_non_digit_key_returns_false" do
      calls = []
      h = make_handler(
        on_move: ->(*args) { calls << [:move, *args] },
        on_fill: ->(*args) { calls << [:fill, *args] },
      )
      result = h.on_key_pressed(
        Gdk::Keyval::KEY_a,
        0,
        0,
        0,
      )
      expect(result).to be(false)
      expect(calls).to eq([])
    end
  end

  # Ported from TestEnterAndRemoveKeys.
  describe "enter and remove keys" do
    it "test_enter_opens_popover" do
      calls = []
      h = make_handler(on_show_popover: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_Return,
        0,
        2,
        3,
      )
      expect(calls).to eq([[2, 3, 0]])
    end

    it "test_backspace_clears" do
      calls = []
      h = make_handler(on_clear: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_BackSpace,
        0,
        2,
        3,
      )
      expect(calls).to eq([[2, 3, false]])
    end

    it "test_delete_clears_all" do
      calls = []
      h = make_handler(on_clear: ->(*args) { calls << args })
      h.on_key_pressed(
        Gdk::Keyval::KEY_Delete,
        0,
        2,
        3,
      )
      expect(calls).to eq([[2, 3, true]])
    end
  end

  # Ported from TestCellClick, adapted: the port's click entry point is the
  # public `#on_cell_clicked(gesture, n_press, row, col)`, fed by a
  # `Gtk::GestureClick`; a minimal double stands in for the gesture the way
  # upstream mocks `Gtk`/`Gdk` wholesale.
  describe "cell click" do
    def fake_gesture(button:, state: 0)
      Object.new.tap do |double|
        double.define_singleton_method(:current_button) { button }
        double.define_singleton_method(:current_event_state) { state }
      end
    end

    it "test_left_click_routes" do
      calls = []
      h = make_handler(on_cell_click: ->(*args) { calls << args })
      h.on_cell_clicked(
        fake_gesture(button: 1),
        1,
        3,
        5,
      )
      expect(calls).to eq([[3, 5, 1, 1]])
    end

    it "test_right_click_routes" do
      calls = []
      h = make_handler(on_cell_click: ->(*args) { calls << args })
      h.on_cell_clicked(
        fake_gesture(button: 3),
        1,
        3,
        5,
      )
      expect(calls).to eq([[3, 5, 3, 1]])
    end
  end
end
