# frozen_string_literal: true

require "adwaita"
require_relative "preferences"
require_relative "preferences_page"

module Sudoku
  # Ported from upstream src/screens/preferences_dialog.py.
  #
  # One preferences page holding the general group and the current variant's
  # group. The dialog edits the live preferences of the game in progress, so
  # it is only reachable while one is being played.
  class PreferencesDialog < Adwaita::PreferencesDialog
    type_register

    def initialize(auto_save)
      super()
      @auto_save = auto_save
      build
    end

    def build
      tap do |dialog|
        dialog.title = "Preferences"
        dialog.search_enabled = false
        dialog.add(page)

        page.tap do |prefs_page|
          prefs_page.add(general_group)
          prefs_page.add(variant_group)
        end
      end
    end

    def page = @page ||= Adwaita::PreferencesPage.new

    def general_group
      @general_group ||= GeneralPreferencesPage.new(
        preferences.general_toggles,
        preferences.general_counted,
        "General",
        @auto_save,
      )
    end

    def variant_group
      @variant_group ||= VariantPreferencesPage.new(
        preferences.variant_defaults,
        preferences.name,
        @auto_save,
      )
    end

    def preferences = @preferences ||= PreferencesManager.get_preferences
  end
end
