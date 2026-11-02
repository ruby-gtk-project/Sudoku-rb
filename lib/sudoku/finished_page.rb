# frozen_string_literal: true

require "gtk4"
require "adwaita"

module Sudoku
  # Ported from upstream src/screens/finished_page.py and
  # data/blueprints/finished-page.blp.
  #
  # The stack page shown when the puzzle is solved: the celebration
  # illustration, in the light or dark variant, over a title. The illustration
  # is chosen when the page is mapped and again whenever the colour scheme
  # changes, as upstream does.
  class FinishedPage < Gtk::Box
    type_register

    VICTORY_MESSAGE = "Puzzle Complete!"
    DARK_PICTURE = "puzzle-complete-celebration-dark.svg"
    LIGHT_PICTURE = "puzzle-complete-celebration-light.svg"

    # A Gtk::Box subclass registered through the Ruby bindings takes no
    # constructor arguments, so the orientation is set as a property instead.
    def initialize
      super()
      self.orientation = :horizontal
      self.spacing = 0
      build
    end

    def build
      tap do |page|
        page.hexpand = true
        page.vexpand = true
        page.margin_bottom = 30
        page.append(outer_box)

        outer_box.tap do |outer|
          outer.append(clamp)

          clamp.tap do |area|
            area.child = content_box

            content_box.tap do |box|
              box.append(picture)
              box.append(finished_label)
            end
          end
        end

        page.signal_connect("map") { on_map }
        style_manager.signal_connect("notify::dark") { update_picture }
      end
    end

    def outer_box
      @outer_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.margin_bottom = 20
        box.halign = :fill
        box.valign = :center
        box.hexpand = true
        box.vexpand = true
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |area|
        area.maximum_size = 1200
        area.tightening_threshold = 300
      end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 12)

    def picture
      @picture ||= Gtk::Picture.new.tap do |image|
        image.halign = :center
        image.valign = :fill
        image.hexpand = true
        image.vexpand = true
        image.margin_bottom = 60
        image.can_shrink = true
        image.content_fit = :contain
      end
    end

    def finished_label
      @finished_label ||= Gtk::Label.new.tap do |label|
        label.wrap = true
        label.justify = :center
        label.add_css_class("title-1")
      end
    end

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    private

      def on_map
        finished_label.label = VICTORY_MESSAGE
        update_picture
      end

      def update_picture
        if style_manager.dark?
          picture.filename = Sudoku.data_path("illustrations", DARK_PICTURE)
        else
          picture.filename = Sudoku.data_path("illustrations", LIGHT_PICTURE)
        end
      end
  end
end
