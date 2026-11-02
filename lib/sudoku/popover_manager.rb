# frozen_string_literal: true

require "gtk4"
require_relative "preferences"
require_relative "log_utils"

module Sudoku
  # Ported from upstream src/shared/popover_manager.py.
  #
  # The number-selection popover: a 3x3 pad of number buttons plus Clear (and
  # Done while in pencil mode), pointed at the cell that was clicked. The
  # popover is parented to the grid rather than the cell, so it survives the
  # cell being re-focused and is thrown away whenever the grid is rebuilt.
  class PopoverManager
    BUTTON_SIZE = 40
    GRID_SPACING = 5
    NUMBERS = (1..9).freeze
    RIGHT_BUTTON = 3

    attr_reader :parent_grid, :pencil_mode

    def initialize(input_handler)
      @input_handler = input_handler
      @parent_grid = nil
      @pencil_mode = false
      @active_popover = nil
      @cell_popover = nil
      @last_popover_cell = nil
      @restore_focus_on_close = false
    end

    def set_parent_grid(parent_grid)
      @parent_grid = parent_grid
      @cell_popover = nil
    end

    def set_pencil_mode(pencil_mode)
      @pencil_mode = pencil_mode
    end

    def get_or_create_popover
      @cell_popover ||= Gtk::Popover.new.tap do |popover|
        popover.position = :bottom
        popover.has_arrow = false
        popover.name = "sudoku-popover"
        popover.set_parent(@parent_grid)
        popover.signal_connect("closed") { on_popover_closed }
      end
    end

    # Dropped whenever the grid goes away: the popover is parented to the old
    # grid and would point at freed geometry.
    def invalidate
      popdown_active_popover
      @cell_popover = nil
      @active_popover = nil
    end

    # Deferred to an idle so the click that opened it has finished being
    # handled before the popover grabs the focus.
    def show_popover(cell, remaining_valid_inputs, button)
      GLib::Idle.add do
        present_popover(cell, remaining_valid_inputs, button)
        false
      end
    end

    def on_number_selected(number, cell, popover, mouse_button)
      @input_handler.handle_fill.call(
        cell.row || 0,
        cell.col || 0,
        number,
        mouse_button == RIGHT_BUTTON,
      )
      if !@pencil_mode && mouse_button != RIGHT_BUTTON
        popover.popdown
      end
    end

    def on_clear_selected(cell, popover)
      @input_handler.handle_clear.call(cell.row || 0, cell.col || 0, true)
      popover.popdown
    end

    private

      def present_popover(cell, remaining_valid_inputs, mouse_button)
        @restore_focus_on_close = false
        popdown_active_popover

        preferences = PreferencesManager.get_preferences
        if @parent_grid && preferences&.general("show_popover")
          get_or_create_popover.tap do |popover|
            point_popover_at_cell(popover, cell)
            popover.child = popover_contents(
              cell,
              popover,
              mouse_button,
              remaining_valid_inputs,
            )
            popover.popup
            @last_popover_cell = cell
            @restore_focus_on_close = true
            @active_popover = popover
          end
        end
      end

      def on_popover_closed
        cell = @last_popover_cell
        restore_focus = @restore_focus_on_close
        @active_popover = nil
        @restore_focus_on_close = false
        @last_popover_cell = nil

        if restore_focus && cell
          GLib::Idle.add do
            cell.grab_focus
            false
          end
        end
      end

      def popdown_active_popover
        if @active_popover
          @restore_focus_on_close = false
          begin
            if @active_popover.visible?
              @active_popover.popdown
            end
          rescue StandardError
            LogUtils.logger.debug("Popover popdown skipped")
          end
        end
      end

      def point_popover_at_cell(popover, cell)
        x, y, width, height = cell_geometry(cell)
        popover.pointing_to = Gdk::Rectangle.new(
          x.to_i,
          y.to_i,
          width.to_i,
          height.to_i,
        )
      end

      # The cell's rectangle in the grid's coordinates, falling back to its own
      # allocation when the two are not yet related.
      def cell_geometry(cell)
        allocation = cell.allocation
        coordinates = cell.translate_coordinates(@parent_grid, 0, 0)
        if coordinates.nil?
          [allocation.x, allocation.y, allocation.width, allocation.height]
        else
          [coordinates[0], coordinates[1], allocation.width, allocation.height]
        end
      end

      def popover_contents(cell, popover, mouse_button, remaining_valid_inputs)
        Gtk::Grid.new.tap do |grid|
          grid.row_spacing = GRID_SPACING
          grid.column_spacing = GRID_SPACING
          grid.focusable = true

          num_buttons = add_number_buttons(
            grid,
            cell,
            popover,
            mouse_button,
            remaining_valid_inputs,
          )
          clear_button = add_action_buttons(
            grid,
            cell,
            popover,
            mouse_button,
          )
          grid.add_controller(@input_handler.make_popover_key_controller(num_buttons, clear_button))
          grid.grab_focus
        end
      end

      def add_number_buttons(grid, cell, popover, mouse_button, remaining_valid_inputs)
        show_remaining = PreferencesManager.get_preferences&.general("show_remaining_valid_inputs")
        {}.tap do |num_buttons|
          NUMBERS.each do |number|
            button = number_button(
              number.to_s,
              cell,
              popover,
              mouse_button,
            )
            count = nil
            if show_remaining
              count = remaining_valid_inputs[number]
            end
            grid.attach(
              number_widget(button, count),
              (number - 1) % 3,
              (number - 1) / 3,
              1,
              1,
            )
            num_buttons[number.to_s] = button
          end
        end
      end

      # A number still to be placed gets its count in the corner; one with none
      # left is shown but cannot be pressed.
      def number_widget(button, count)
        if count.nil?
          button
        elsif count.positive?
          counter_overlay(button, count)
        else
          button.tap { |disabled| disabled.sensitive = false }
        end
      end

      def number_button(label, cell, popover, mouse_button)
        Gtk::Button.new(label: label).tap do |button|
          button.set_size_request(BUTTON_SIZE, BUTTON_SIZE)
          button.signal_connect("clicked") do
            on_number_selected(
              label,
              cell,
              popover,
              mouse_button,
            )
          end
        end
      end

      def counter_overlay(button, count)
        Gtk::Overlay.new.tap do |overlay|
          overlay.child = button
          overlay.add_overlay(corner_label(count))
        end
      end

      def corner_label(count)
        Gtk::Label.new(count.to_s).tap do |label|
          label.halign = :end
          label.valign = :start
          label.margin_start = 2
          label.margin_end = 3
          label.margin_top = 2
          label.margin_bottom = 2
          label.add_css_class("corner-label")
        end
      end

      # Returns the Clear button, which the popover's key controller presses on
      # Delete and Backspace.
      def add_action_buttons(grid, cell, popover, mouse_button)
        clear_button(cell, popover).tap do |clear|
          Gtk::Box.new(:horizontal, GRID_SPACING).tap do |box|
            box.append(clear)
            if @pencil_mode || mouse_button == RIGHT_BUTTON
              box.append(done_button(popover))
            end
            grid.attach(
              box,
              0,
              3,
              3,
              1,
            )
          end
        end
      end

      def clear_button(cell, popover)
        Gtk::Button.new(label: "Clear").tap do |button|
          button.set_size_request(-1, BUTTON_SIZE)
          button.hexpand = true
          button.tooltip_text = "Clear Cell (Del/Backspace)"
          button.signal_connect("clicked") { on_clear_selected(cell, popover) }
        end
      end

      def done_button(popover)
        Gtk::Button.new(label: "Done").tap do |button|
          button.set_size_request(-1, BUTTON_SIZE)
          button.hexpand = true
          button.tooltip_text = "Finish Editing Cell"
          button.signal_connect("clicked") { popover.popdown }
        end
      end
  end
end
