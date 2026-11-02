# frozen_string_literal: true

require "gtk4"
require "adwaita"

module Sudoku
  # Ported from upstream src/screens/game_setup_dialog.py.
  #
  # The New Game dialog: one boxed list of variants, one of difficulties, and
  # a Start Game button that hands the pair to the window.
  class GameSetupDialog < Adwaita::Dialog
    type_register

    EASY_DIFFICULTY = 0.2
    MEDIUM_DIFFICULTY = 0.5
    HARD_DIFFICULTY = 0.7
    EXTREME_DIFFICULTY = 0.9

    VARIANTS = [
      ["Classic Sudoku", "classic"],
      ["Diagonal Sudoku", "diagonal"],
    ].freeze

    DIFFICULTIES = [
      ["Easy", EASY_DIFFICULTY],
      ["Medium", MEDIUM_DIFFICULTY],
      ["Hard", HARD_DIFFICULTY],
      ["Extreme", EXTREME_DIFFICULTY],
    ].freeze

    attr_reader :selected_variant, :selected_difficulty

    def initialize(on_select)
      super()
      @on_select = on_select
      @selected_variant = "classic"
      @selected_difficulty = EASY_DIFFICULTY
      build
    end

    def build
      tap do |dialog|
        dialog.title = "New Game"
        dialog.content_width = 410
        dialog.content_height = 490
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scroll

          scroll.tap do |area|
            area.child = main_box

            main_box.tap do |box|
              box.append(variant_list)
              box.append(difficulty_list)
              box.append(start_button)

              add_radio_rows(variant_list, VARIANTS, @selected_variant) do |value|
                @selected_variant = value
              end

              add_radio_rows(difficulty_list, DIFFICULTIES, @selected_difficulty) do |value|
                @selected_difficulty = value
              end
            end
          end
        end

        dialog.signal_connect("realize") { dialog.set_focus(start_button) }
        start_button.signal_connect("clicked") { on_confirm_clicked }
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def scroll
      @scroll ||= Gtk::ScrolledWindow.new.tap do |area|
        area.set_policy(:never, :automatic)
      end
    end

    def main_box
      @main_box ||= Gtk::Box.new(:vertical, 16).tap do |box|
        box.margin_top = 12
        box.margin_start = 12
        box.margin_end = 12
        box.margin_bottom = 12
      end
    end

    def variant_list = @variant_list ||= boxed_list
    def difficulty_list = @difficulty_list ||= boxed_list

    def start_button
      @start_button ||= Gtk::Button.new(label: "Start Game").tap do |button|
        button.add_css_class("pill")
        button.add_css_class("suggested-action")
        button.halign = :center
        button.hexpand = false
      end
    end

    private

      def boxed_list
        Gtk::ListBox.new.tap do |list|
          list.add_css_class("boxed-list")
          list.selection_mode = :none
        end
      end

      # One activatable row per choice, all sharing a radio group, with the
      # current choice pre-selected. The block is called with the value the
      # player picked.
      def add_radio_rows(list, items, default, &on_selected)
        group = nil
        items.each do |(label, value)|
          radio = radio_button(group)
          group ||= radio
          if value == default
            radio.active = true
          end
          radio.signal_connect("toggled") do
            if radio.active?
              on_selected.call(value)
            end
          end
          list.append(radio_row(label, radio))
        end
      end

      def radio_button(group)
        Gtk::CheckButton.new.tap do |radio|
          radio.add_css_class("radio")
          radio.valign = :center
          radio.halign = :center
          if group
            radio.group = group
          end
        end
      end

      def radio_row(label, radio)
        Adwaita::ActionRow.new.tap do |row|
          row.title = label
          row.add_prefix(radio)
          row.activatable_widget = radio
          row.signal_connect("activated") { radio.active = true }
        end
      end

      def on_confirm_clicked
        @on_select.call(@selected_variant, @selected_difficulty)
        close
      end
  end
end
