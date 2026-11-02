# frozen_string_literal: true

require "gtk4"
require "adwaita"

module Sudoku
  # Ported from upstream data/style.css and data/style-dark.css.
  #
  # Upstream ships the two stylesheets in its gresource bundle, where GTK picks
  # the dark one up by name. The port has no bundle, so the rules live here and
  # the dark provider is added and removed as the system's colour scheme
  # changes.
  module Style
    LIGHT = <<~CSS
      .sudoku-main-window {
          background-color: #e2b97d;
      }

      .icon-dropshadow {
          -gtk-icon-shadow: 0 1px 4px rgba(0,0,0,0.3), 0 3px 20px rgba(0,0,0,0.2);
      }

      #sudoku-parent-grid {
          padding: 50px;
      }

      #sudoku-parent-grid button {
          background-color: rgba(255, 245, 230, 0.6);
      }

      #sudoku-popover button {
          background-color: rgba(255, 227, 185, 0.85);
      }

      #sudoku-parent-grid button.toggle-active {
          background-color: #f9eed7;
          box-shadow: 0 0 10px #d2a56d66;
      }

      #sudoku-parent-grid button:hover {
          background-color: rgba(255, 245, 230, 0.85);
      }

      #sudoku-parent-grid button:checked {
          background-color: #f9eed7;
      }

      .entry-cell {
          color: rgba(28, 20, 15, 0.95);
          font-size: 20px;
      }

      .clue-cell {
          color: rgba(28, 20, 15, 0.65);
          font-size: 20px;
      }

      .sudoku-cell-button {
          min-width: 10px;
          min-height: 10px;
      }

      #sudoku-parent-grid button.entry-cell.correct {
          background-color: rgba(168, 208, 78, 0.55);
          transition: background-color 0.3s ease-in-out;
      }

      #sudoku-parent-grid button.entry-cell.wrong {
          background-color: rgba(226, 116, 74, 0.55);
      }

      #sudoku-parent-grid button.entry-cell.correct.highlight {
          background-color: rgba(190, 220, 90, 0.68);
      }

      #sudoku-parent-grid button.entry-cell.wrong.highlight {
          background-color: rgba(236, 136, 96, 0.68);
      }

      #sudoku-parent-grid button.conflict {
          background-color: rgba(226, 116, 74, 0.45);
          animation: pulse 3s;
      }

      #sudoku-parent-grid button.entry-cell.highlight,
      #sudoku-parent-grid button.clue-cell.highlight {
          background-color: #fff5e3;
          box-shadow: 0 0 10px #d2a56d79;
          transition: background-color 0.3s ease-in-out;
      }

      @keyframes pulse {
          20% { background-color: rgba(236, 136, 96, 0.68); }
          80% { background-color: rgba(236, 136, 96, 0.68); }
      }

      .note-cell-label {
          font-size: 11px;
          padding: 0.8px;
          color: rgba(28, 20, 15, 0.75);
      }

      .large  .entry-cell,
      .large  .clue-cell {
          font-size: 30px;
      }

      .large .note-cell-label {
          font-size: 15px;
          padding: 3px;
      }

      .compact-mode #sudoku-parent-grid {
          border-radius: 6px;
      }

      .compact-mode  .entry-cell,
      .compact-mode  .clue-cell {
          font-size: 20px;
      }

      .compact-mode .note-cell-label {
          font-size: 10px;
          padding: 0.4px;
      }

      .small-mode #sudoku-parent-grid {
          padding: 10px;
          border-radius: 6px;
      }

      .small-mode  .entry-cell,
      .small-mode .clue-cell {
          font-size: 17px;
      }

      .small-mode .note-cell-label {
          font-size: 7px;
          padding: 0.2px;
      }

      .corner-label {
          font-size: 13px;
          opacity: 0.5;
      }
    CSS

    DARK = <<~CSS
      .sudoku-main-window {
          background-color: #553525;
      }

      #sudoku-parent-grid button {
          background-color: rgba(236, 210, 180, 0.25);
      }

      #sudoku-parent-grid button.toggle-active {
          background-color: #e8cfae;
          box-shadow: 0 0 12px #e8cfae55;
      }

      #sudoku-parent-grid button:hover {
          background-color: rgba(236, 210, 180, 0.35);
      }

      #sudoku-parent-grid button:checked {
          background-color: #e8cfae;
      }

      #sudoku-parent-grid button.entry-cell.highlight,
      #sudoku-parent-grid button.clue-cell.highlight {
          background-color: #9b7f72;
          box-shadow: 0 0 12px #e0c6a333;
          transition: background-color 0.3s ease-in-out;
      }

      #sudoku-parent-grid button.entry-cell.correct {
          background-color: rgba(150, 190, 110, 0.50);
      }

      #sudoku-parent-grid button.entry-cell.wrong {
          background-color: rgba(220, 130, 100, 0.55);
      }

      #sudoku-parent-grid button.entry-cell.correct.highlight {
          background-color: rgba(172, 206, 126, 0.55);
      }

      #sudoku-parent-grid button.entry-cell.wrong.highlight {
          background-color: rgba(236, 146, 116, 0.68);
      }

      #sudoku-parent-grid button.conflict {
          background-color: rgba(220, 130, 100, 0.48);
      }

      @keyframes pulse {
          20% { background-color: rgba(236, 146, 116, 0.68); }
          80% { background-color: rgba(236, 146, 116, 0.68); }
      }

      .entry-cell {
          color: rgba(252, 244, 235, 1);
      }

      .clue-cell {
          color: rgba(252, 244, 235, 0.72);
      }

      .note-cell-label {
          color: #ebd6c0;
      }
    CSS

    LIGHT_PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION
    DARK_PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION + 1

    class << self
      # Adds the light stylesheet, adds the dark one on top while the system is
      # in dark mode, and keeps following the colour scheme. Also puts the
      # app's own icon directory on the icon theme's search path, since the
      # port installs no icons.
      def install(display = Gdk::Display.default)
        if display
          Gtk::StyleContext.add_provider_for_display(display, light_provider, LIGHT_PRIORITY)
          add_icon_search_path(display)
          follow_color_scheme(display)
        end
      end

      def light_provider
        @light_provider ||= Gtk::CssProvider.new.tap { |provider| provider.load(data: LIGHT) }
      end

      def dark_provider
        @dark_provider ||= Gtk::CssProvider.new.tap { |provider| provider.load(data: DARK) }
      end

      private

        def follow_color_scheme(display)
          Adwaita::StyleManager.default.tap do |manager|
            manager.signal_connect("notify::dark") { apply_color_scheme(display, manager) }
            apply_color_scheme(display, manager)
          end
        end

        def apply_color_scheme(display, manager)
          if manager.dark?
            Gtk::StyleContext.add_provider_for_display(display, dark_provider, DARK_PRIORITY)
          else
            Gtk::StyleContext.remove_provider_for_display(display, dark_provider)
          end
        end

        def add_icon_search_path(display)
          Gtk::IconTheme.get_for_display(display).add_search_path(Sudoku.data_path("icons"))
        end
    end
  end
end
