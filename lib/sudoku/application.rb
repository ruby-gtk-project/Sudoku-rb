# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "help_dialog"
require_relative "log_utils"
require_relative "shortcuts_dialog"
require_relative "style"
require_relative "window"
require_relative "rb/version"

module Sudoku
  # Ported from upstream src/application.py.
  #
  # The application object: it sets up logging, installs the stylesheets,
  # registers the application actions and their accelerators, and presents the
  # main window.
  #
  # Adwaita::Application is broken in the Ruby bindings, so the application
  # object comes from Gtk and only the window is Adwaita.
  class Application
    APPLICATION_ID = "org.rubygtkproject.Sudoku"

    # action name => its accelerators
    ACTIONS = {
      "quit"        => ["<primary>q", "<primary>w"],
      "about"       => [],
      "how_to_play" => ["F1"],
      "shortcuts"   => ["<Ctrl>question"],
    }.freeze

    WINDOW_ACCELERATORS = {
      "win.pencil-toggled"    => ["p"],
      "win.back-to-menu"      => ["<Ctrl>m"],
      "win.show-primary-menu" => ["F10"],
      "win.show-preferences"  => ["<primary>comma"],
      "win.auto-pencil-marks" => ["<Shift>p"],
    }.freeze

    def initialize(version = Rb::VERSION)
      @version = version
      @log_handler = LogUtils.setup_logging
    end

    def build
      app.tap do |application|
        application.signal_connect("startup") do
          Style.install
          setup_actions
          setup_accelerators
        end

        application.signal_connect("activate") do
          window.present
        end
      end
    end

    def run = app.run([])

    def app = @app ||= Gtk::Application.new(APPLICATION_ID, :default_flags)

    def window = @window ||= SudokuWindow.new(app)

    # --- Actions ------------------------------------------------------------

    def on_quit
      app.quit
    end

    def on_about
      about_dialog.present(window)
    end

    def on_how_to_play
      HowToPlayDialog.new.present(window)
    end

    def on_shortcuts
      ShortcutsDialog.build.present(window)
    end

    def about_dialog
      Adwaita::AboutDialog.new.tap do |dialog|
        dialog.application_name = "Sudoku"
        dialog.application_icon = "io.github.sepehr_rs.Sudoku"
        dialog.developer_name = "Sepehr"
        dialog.version = @version
        dialog.developers = ["Sepehr", "Revisto"]
        dialog.copyright = "© 2025 sepehr-rs"
        dialog.license_type = Gtk::License::GPL_3_0
        dialog.debug_info = debug_info
        dialog.issue_url = "https://github.com/sepehr-rs/sudoku/issues"
      end
    end

    # The report the about dialog's "Troubleshooting" section shows, with the
    # session's log at the end.
    def debug_info
      [
        "Sudoku #{@version}",
        "System: #{RbConfig::CONFIG['host_os']}",
        "Ruby #{RUBY_VERSION}",
        "GTK #{Gtk::Version::MAJOR}.#{Gtk::Version::MINOR}.#{Gtk::Version::MICRO}",
        "Adwaita #{Adwaita::MAJOR_VERSION}.#{Adwaita::MINOR_VERSION}.#{Adwaita::MICRO_VERSION}",
        "",
        "--- Logs ---",
        @log_handler.logs,
      ].join("\n")
    end

    private

      def setup_actions
        ACTIONS.each_key do |name|
          Gio::SimpleAction.new(name, nil).tap do |action|
            action.signal_connect("activate") { activate_action(name) }
            app.add_action(action)
          end
          accelerators = ACTIONS.fetch(name)
          unless accelerators.empty?
            app.set_accels_for_action("app.#{name}", accelerators)
          end
        end
      end

      def activate_action(name)
        case name
        when "quit" then on_quit
        when "about" then on_about
        when "how_to_play" then on_how_to_play
        when "shortcuts" then on_shortcuts
        end
      end

      def setup_accelerators
        WINDOW_ACCELERATORS.each do |action, accelerators|
          app.set_accels_for_action(action, accelerators)
        end
      end
  end
end
