# frozen_string_literal: true

require "adwaita"
require_relative "translations"

module Sudoku
  # Ported from upstream data/blueprints/shortcuts-dialog.blp.
  #
  # The keyboard shortcuts window, built from the same sections and
  # accelerators the blueprint declares.
  #
  # Adwaita::ShortcutsDialog cannot be subclassed through the Ruby bindings
  # (type registration is refused), so the dialog is assembled here and handed
  # back ready to present.
  module ShortcutsDialog
    include Gettext

    # Upstream's blueprint marks every one of these with C_("shortcut
    # window", ...), so each carries that context into the catalogue — the
    # context is spelled out at every call because that is what the extractor
    # reads.
    SECTIONS = [
      [
        p_("shortcut window", "Game"),
        [
          [p_("shortcut window", "Move Between Cells"), "Up Down Left Right"],
          [p_("shortcut window", "Jump Between Blocks"), "<Primary>Up Down Left Right"],
        ],
      ],
      [
        p_("shortcut window", "Pencil"),
        [
          [p_("shortcut window", "Pencil Mode"), "P"],
          [p_("shortcut window", "Auto Pencil Marks"), "<Shift>P"],
          [p_("shortcut window", "Place Pencil Mark"), "<Primary>1...9"],
        ],
      ],
      [
        p_("shortcut window", "Input"),
        [
          [p_("shortcut window", "Open Number Pop-Up"), "Return"],
        ],
      ],
      [
        p_("shortcut window", "General"),
        [
          [p_("shortcut window", "Show Shortcuts"), "<Primary>question"],
          [p_("shortcut window", "Back to Main Menu"), "<Primary>M"],
          [p_("shortcut window", "How to Play"), "F1"],
          [p_("shortcut window", "Quit"), "<Primary>Q <Primary>W"],
        ],
      ],
    ].freeze

    def self.build
      Adwaita::ShortcutsDialog.new.tap do |dialog|
        SECTIONS.each do |(title, items)|
          dialog.add(section(title, items))
        end
      end
    end

    def self.section(title, items)
      Adwaita::ShortcutsSection.new.tap do |group|
        group.title = title
        items.each { |(item_title, accelerator)| group.add(item(item_title, accelerator)) }
      end
    end

    def self.item(title, accelerator) = Adwaita::ShortcutsItem.new(title, accelerator)
  end
end
