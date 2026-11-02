# frozen_string_literal: true

require "gtk4"
require "adwaita"

module Sudoku
  # The preference key as a row title: "auto_remove_notes" reads
  # "Auto Remove Notes", which is upstream's key.replace("_", " ").title().
  module PreferenceTitle
    def self.of(key)
      key.to_s.tr("_", " ").split(" ").map(&:capitalize).join(" ")
    end
  end

  # The two row shapes both preference groups build: a switch, and the action
  # row carrying it with the preference's tooltip as its subtitle.
  module PreferenceRows
    private

      def toggle_switch(active)
        Gtk::Switch.new.tap do |switch|
          switch.valign = :center
          switch.active = active == true
        end
      end

      def labelled_row(title, subtitle, switch)
        Adwaita::ActionRow.new.tap do |row|
          row.title = title
          unless subtitle.to_s.empty?
            row.subtitle = subtitle
          end
          row.add_suffix(switch)
          row.activatable_widget = switch
        end
      end
  end

  # Ported from upstream src/screens/preferences_page.py
  # (VariantPreferencesPage).
  #
  # The variant's own switches, titled after the variant. Every change writes
  # straight through to the live preferences and calls the auto-save hook, so
  # there is no OK button to press.
  class VariantPreferencesPage < Adwaita::PreferencesGroup
    type_register
    include PreferenceRows

    attr_reader :controls

    def initialize(variant_preferences, name, auto_save)
      super()
      @variant_preferences = variant_preferences
      @auto_save = auto_save
      @controls = {}
      self.title = name
      build
    end

    def build
      tap do
        @variant_preferences.each_key { |key| add_switch_row(key) }
      end
    end

    private

      def add_switch_row(key)
        switch = toggle_switch(@variant_preferences[key])
        @controls[key] = switch
        switch.signal_connect("notify::active") { on_toggle_changed(key, switch) }
        add(labelled_row(PreferenceTitle.of(key), nil, switch))
      end

      def on_toggle_changed(key, switch)
        @variant_preferences[key] = switch.active?
        @auto_save.call
      end
  end

  # Ported from upstream src/screens/preferences_page.py
  # (GeneralPreferencesPage).
  #
  # The switches every variant shares, plus the counted mistake limit: a
  # switch that enables it and a spin row for the count, which is insensitive
  # while the limit is off.
  class GeneralPreferencesPage < Adwaita::PreferencesGroup
    type_register
    include PreferenceRows

    MIN_COUNT = 1
    MAX_COUNT = 20

    attr_reader :controls

    def initialize(general_toggles, general_counted, name, auto_save)
      super()
      @general_toggles = general_toggles
      @general_counted = general_counted
      @auto_save = auto_save
      @controls = {}
      self.title = name
      build
    end

    def build
      tap do
        @general_toggles.each { |key, entry| add_bool_row(key, entry) }
        @general_counted.each { |key, entry| add_counted_rows(key, entry) }
      end
    end

    private

      def add_bool_row(key, entry)
        switch = toggle_switch(entry.fetch("value", false))
        @controls[key] = switch
        switch.signal_connect("notify::active") { on_bool_changed(key, switch) }
        add(labelled_row(PreferenceTitle.of(key), entry.fetch("tooltip", ""), switch))
      end

      def add_counted_rows(key, entry)
        switch = toggle_switch(entry["enabled"])
        add(labelled_row(PreferenceTitle.of(key), entry.fetch("tooltip", ""), switch))

        count_row(entry).tap do |spin_row|
          add(spin_row)
          @controls[key] = [switch, spin_row]
          switch.signal_connect("notify::active") do
            on_counted_toggle_changed(key, switch, spin_row)
          end
          spin_row.signal_connect("notify::value") { on_count_changed(key, spin_row) }
        end
      end

      def count_row(entry)
        adjustment = Gtk::Adjustment.new(
          entry["count"].to_f,
          MIN_COUNT,
          MAX_COUNT,
          1,
          1,
          0,
        )
        Adwaita::SpinRow.new(adjustment, 1, 0).tap do |spin_row|
          spin_row.title = "Mistake limit"
          spin_row.sensitive = entry["enabled"] == true
        end
      end

      def on_bool_changed(key, switch)
        @general_toggles[key]["value"] = switch.active?
        @auto_save.call
      end

      def on_counted_toggle_changed(key, switch, spin_row)
        @general_counted[key]["enabled"] = switch.active?
        spin_row.sensitive = switch.active?
        @auto_save.call
      end

      def on_count_changed(key, spin_row)
        @general_counted[key]["count"] = spin_row.value.to_i
        @auto_save.call
      end
  end
end
