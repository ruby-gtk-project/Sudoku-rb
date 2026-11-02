# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "classic_sudoku"
require_relative "diagonal_sudoku"
require_relative "finished_page"
require_relative "game_over_page"
require_relative "game_setup_dialog"
require_relative "loading_screen"
require_relative "persistence"
require_relative "preferences"
require_relative "preferences_dialog"

module Sudoku
  # Ported from upstream src/window.py and data/blueprints/window.blp.
  #
  # The main window: a header bar over a stack that holds the main menu, the
  # game grid, the loading screen and the two end-of-game pages. It owns the
  # window actions, the breakpoints that drive compact mode, and the controller
  # of the game being played.
  class SudokuWindow < Adwaita::ApplicationWindow
    type_register

    DIFFICULTY_LABELS = {
      GameSetupDialog::EASY_DIFFICULTY    => "Easy",
      GameSetupDialog::MEDIUM_DIFFICULTY  => "Medium",
      GameSetupDialog::HARD_DIFFICULTY    => "Hard",
      GameSetupDialog::EXTREME_DIFFICULTY => "Extreme",
    }.freeze

    BREAKPOINTS = [
      ["min-width: 800px and min-height: 800px", "large"],
      ["max-width: 650px or max-height: 700px", "compact"],
      ["max-width: 550px or max-height: 550px", "small"],
    ].freeze

    MODE_CSS_CLASSES = {
      "large"   => "large",
      "compact" => "compact-mode",
      "small"   => "small-mode",
    }.freeze

    COMPACT_MODES = ["compact", "small"].freeze

    WINDOW_ACTIONS = [
      "show-primary-menu",
      "back-to-menu",
      "pencil-toggled",
      "show-preferences",
      "auto-pencil-marks",
    ].freeze

    attr_reader :controller

    def initialize(app)
      super()
      self.application = app
      @controller = nil
      @is_game_page = false
      build
    end

    def build
      tap do |window|
        window.title = "Sudoku"
        window.add_css_class("sudoku-main-window")
        window.set_default_size(710, 810)
        window.set_size_request(360, 420)
        window.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = bp_bin

          header_bar.tap do |bar|
            bar.title_widget = sudoku_window_title
            bar.pack_start(home_button)
            bar.pack_end(primary_menu_button)
            bar.pack_end(pencil_toggle_button)
          end

          bp_bin.child = stack

          stack.tap do |pages|
            pages.add_named(main_menu_box, "main-menu")
            pages.add_named(game_scrolled_window, "game")
            pages.add_named(finished_page, "finished")
            pages.add_named(game_over_page, "game-over")
            pages.add_named(loading_screen, "loading")
          end

          main_menu_box.child = main_menu_status_page
          main_menu_status_page.child = menu_box

          menu_box.tap do |box|
            box.append(main_menu_icon)
            box.append(continue_button)
            box.append(new_game_button)
          end

          game_scrolled_window.child = grid_container
        end

        add_window_actions
        add_breakpoints
        connect_buttons
        build_primary_menu(show_game_actions: false)
        window.add_controller(window_gesture)
        stack.signal_connect("notify::visible-child") { on_stack_page_changed }
        on_stack_page_changed
      end
    end

    # --- Actions ------------------------------------------------------------

    def on_show_primary_menu
      primary_menu_button.popup
    end

    def on_back_to_menu
      Persistence.save_preferences
      continue_button.visible = Persistence.saved_game?
      update_sudoku_window_subtitle("")
      stack.visible_child = main_menu_box
      pencil_toggle_button.visible = false
      PreferencesManager.set_preferences(nil)
      build_primary_menu(show_game_actions: false)
    end

    def on_auto_pencil_marks
      if @controller&.board
        @controller.apply_auto_pencil_marks
      end
    end

    # Preferences edit the game in progress, so every change is saved and the
    # subtitle refreshed straight away.
    def on_show_preferences
      if @controller
        PreferencesDialog.new(method(:save_game_preferences)).present(self)
      end
    end

    def on_pencil_toggled_action
      if @is_game_page
        pencil_toggle_button.active = !pencil_toggle_button.active?
        change_subtitle_for_pencil_mode
      end
    end

    # --- Game lifecycle -----------------------------------------------------

    def controller_and_preferences_for(variant)
      case variant
      when "classic", Persistence::UNKNOWN_VARIANT
        [ClassicSudokuController.new(self), ClassicSudokuPreferences.new]
      when "diagonal"
        [DiagonalSudokuController.new(self), DiagonalSudokuPreferences.new]
      else
        raise ArgumentError, "Unknown Sudoku variant: #{variant}"
      end
    end

    def on_continue_clicked
      variant = Persistence.variant
      if variant
        start_variant(variant)
        Persistence.migrate_preferences_from_board
        @controller.load_saved_game
        setup_game_ui
      else
        continue_button.visible = false
      end
    end

    def on_new_game_clicked
      GameSetupDialog.new(method(:on_game_setup_selected)).present(self)
    end

    def on_game_setup_selected(variant_name, difficulty)
      start_variant(variant_name)
      label = DIFFICULTY_LABELS.fetch(difficulty, difficulty.to_s)
      update_sudoku_window_subtitle("#{variant_name.capitalize} • #{label}")
      setup_game_ui
      @controller.start_game(difficulty, label, variant_name)
    end

    # --- Header bar ---------------------------------------------------------

    def update_sudoku_window_subtitle(subtitle)
      sudoku_window_title.subtitle = subtitle
    end

    # --- Layout -------------------------------------------------------------

    # Adds or removes the breakpoint's CSS class and, for the narrow modes,
    # lets the controller retune the grid's spacing.
    def apply_mode(enabled, mode)
      target = bp_bin
      css_class = MODE_CSS_CLASSES.fetch(mode)
      if enabled
        target.add_css_class(css_class)
      else
        target.remove_css_class(css_class)
      end

      if COMPACT_MODES.include?(mode) && @controller
        @controller.apply_compact_mode(enabled, mode)
      end
    end

    # The chain from the breakpoint bin down to the grid has to expand for the
    # board to stay square and centred; upstream sets the same flags from the
    # controller.
    def expand_game_area
      [game_scrolled_window, grid_container, bp_bin, stack].each do |widget|
        widget.hexpand = true
        widget.vexpand = true
      end
      [bp_bin, stack].each do |widget|
        widget.halign = :fill
        widget.valign = :fill
      end
    end

    # --- Widgets ------------------------------------------------------------

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def sudoku_window_title = @sudoku_window_title ||= Adwaita::WindowTitle.new("Sudoku", "")

    def home_button
      @home_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "go-previous-symbolic"
        button.tooltip_text = "Back to Main Menu"
        button.action_name = "win.back-to-menu"
      end
    end

    def primary_menu_button
      @primary_menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = "Menu"
      end
    end

    def pencil_toggle_button
      @pencil_toggle_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = "document-edit-symbolic"
        button.tooltip_text = "Toggle Pencil Mode"
      end
    end

    def bp_bin = @bp_bin ||= Adwaita::BreakpointBin.new

    def stack
      @stack ||= Gtk::Stack.new.tap do |pages|
        pages.transition_type = :crossfade
        pages.transition_duration = 300
      end
    end

    def main_menu_box
      @main_menu_box ||= Gtk::ScrolledWindow.new.tap do |area|
        area.set_policy(:never, :never)
        area.hexpand = true
        area.vexpand = true
      end
    end

    def main_menu_status_page = @main_menu_status_page ||= Adwaita::StatusPage.new

    def menu_box
      @menu_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.halign = :center
        box.valign = :center
      end
    end

    def main_menu_icon
      @main_menu_icon ||= Gtk::Image.new.tap do |image|
        image.icon_name = "io.github.sepehr_rs.Sudoku"
        image.pixel_size = 256
        image.halign = :center
        image.valign = :center
        image.margin_bottom = 65
        image.add_css_class("icon-dropshadow")
      end
    end

    def continue_button
      @continue_button ||= Gtk::Button.new(label: "Continue Game").tap do |button|
        button.use_underline = true
        button.add_css_class("pill")
      end
    end

    def new_game_button
      @new_game_button ||= Gtk::Button.new(label: "New Game").tap do |button|
        button.use_underline = true
        button.add_css_class("pill")
      end
    end

    def game_scrolled_window
      @game_scrolled_window ||= Gtk::ScrolledWindow.new.tap do |area|
        area.set_policy(:automatic, :automatic)
        area.hexpand = true
        area.vexpand = true
      end
    end

    def grid_container
      @grid_container ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.hexpand = true
        box.vexpand = true
      end
    end

    def finished_page = @finished_page ||= FinishedPage.new
    def game_over_page = @game_over_page ||= GameOverPage.new
    def loading_screen = @loading_screen ||= LoadingScreen.new

    def window_gesture
      @window_gesture ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = 0
        gesture.propagation_phase = :capture
        gesture.signal_connect("pressed") do |pressed, _n_press, x, y|
          on_window_pressed(pressed, x, y)
        end
      end
    end

    private

      def add_window_actions
        WINDOW_ACTIONS.each do |name|
          Gio::SimpleAction.new(name, nil).tap do |action|
            action.signal_connect("activate") { activate_window_action(name) }
            add_action(action)
          end
        end
      end

      def activate_window_action(name)
        case name
        when "show-primary-menu" then on_show_primary_menu
        when "back-to-menu" then on_back_to_menu
        when "pencil-toggled" then on_pencil_toggled_action
        when "show-preferences" then on_show_preferences
        when "auto-pencil-marks" then on_auto_pencil_marks
        end
      end

      def add_breakpoints
        BREAKPOINTS.each do |(condition, mode)|
          Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(condition)).tap do |point|
            point.signal_connect("apply") { apply_mode(true, mode) }
            point.signal_connect("unapply") { apply_mode(false, mode) }
            add_breakpoint(point)
          end
        end
      end

      def connect_buttons
        continue_button.tap do |button|
          button.signal_connect("clicked") { on_continue_clicked }
          button.tooltip_text = "Continue Saved Game"
          button.visible = Persistence.saved_game?
        end
        new_game_button.tap do |button|
          button.signal_connect("clicked") { on_new_game_clicked }
          button.tooltip_text = "Start a New Game"
        end
        pencil_toggle_button.signal_connect("toggled") { on_pencil_toggled_button }
        home_button.visible = false
      end

      def start_variant(variant_name)
        @controller, preferences = controller_and_preferences_for(variant_name)
        PreferencesManager.set_preferences(preferences)
        Persistence.apply_variant_preferences(variant_name)
      end

      def setup_game_ui
        pencil_toggle_button.active = false
        lookup_action("show-preferences").enabled = true
        build_primary_menu(show_game_actions: true)
      end

      def save_game_preferences
        Persistence.save_preferences
        @controller.board.save
        @controller.update_subtitle
      end

      # Everything that depends on which page is showing: pencil mode is only
      # available on the game page, the back arrow only away from the menu and
      # the loading screen.
      def on_stack_page_changed
        visible = stack.visible_child
        if non_game_pages.include?(visible)
          force_disable_pencil_mode
          update_sudoku_window_subtitle("")
        end

        is_game_page = !non_game_pages.include?(visible)
        is_menu_or_loading = [main_menu_box, loading_screen].include?(visible)

        build_primary_menu(show_game_actions: is_game_page)
        lookup_action("show-preferences").enabled = is_game_page
        lookup_action("auto-pencil-marks").enabled = is_game_page
        lookup_action("show-primary-menu").enabled = is_game_page
        lookup_action("back-to-menu").enabled = !is_menu_or_loading
        pencil_toggle_button.visible = is_game_page
        home_button.visible = !is_menu_or_loading
        primary_menu_button.visible = is_game_page

        @is_game_page = is_game_page
        if is_game_page
          change_subtitle_for_pencil_mode
        end
      end

      def non_game_pages
        [main_menu_box, loading_screen, finished_page, game_over_page]
      end

      def force_disable_pencil_mode
        if pencil_toggle_button.active?
          pencil_toggle_button.active = false
        end
        if @controller
          @controller.pencil_mode = false
        end
      end

      def on_pencil_toggled_button
        if @controller
          change_subtitle_for_pencil_mode
          @controller.on_pencil_toggled(pencil_toggle_button)
        end
      end

      # Pencil mode takes the subtitle over while it is on; otherwise the
      # subtitle names the variant, the difficulty and the mistake count.
      def change_subtitle_for_pencil_mode
        preferences = PreferencesManager.get_preferences
        board = @controller&.board
        showing_game = !non_game_pages.include?(stack.visible_child)

        if preferences && board && showing_game
          if pencil_toggle_button.active?
            update_sudoku_window_subtitle("Pencil Mode • Note possible numbers")
          else
            @controller.update_subtitle
          end
        end
      end

      def build_primary_menu(show_game_actions: true)
        Gio::Menu.new.tap do |menu|
          Gio::Menu.new.tap do |section|
            section.append("Keyboard Shortcuts", "app.shortcuts")
            if show_game_actions
              section.append("Preferences", "win.show-preferences")
              section.append("Auto Pencil Marks", "win.auto-pencil-marks")
            end
            section.append("How To Play", "app.how_to_play")
            section.append("About Sudoku", "app.about")
            menu.append_section(nil, section)
          end
          primary_menu_button.menu_model = menu
        end
      end

      # A left click outside the board drops the highlight the selected cell
      # put on its row, column and block.
      def on_window_pressed(gesture, x, y)
        if gesture.current_button == 1 && @controller
          frame = grid_container.first_child
          grid = frame&.child
          coordinates = grid&.translate_coordinates(self, 0, 0)
          if coordinates && outside?(
            grid,
            coordinates,
            x,
            y,
          )
            @controller.on_grid_unfocus
          end
        end
      end

      def outside?(grid, coordinates, x, y)
        allocation = grid.allocation
        inside_x = (coordinates[0]...(coordinates[0] + allocation.width)).cover?(x)
        inside_y = (coordinates[1]...(coordinates[1] + allocation.height)).cover?(y)
        !(inside_x && inside_y)
      end
  end
end
