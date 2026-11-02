# frozen_string_literal: true

require "gtk4"
require "adwaita"

module Sudoku
  # Ported from upstream src/screens/game_over_page.py and
  # data/blueprints/game-over-page.blp.
  #
  # The stack page shown when the mistake limit is reached. The same layout as
  # the finished page, with one illustration for both colour schemes —
  # upstream has yet to draw the dark variant.
  class GameOverPage < Gtk::Box
    type_register

    GAMEOVER_MESSAGE = "Game Over!"
    PICTURE = "puzzle-game-over.svg"

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

    private

      def on_map
        finished_label.label = GAMEOVER_MESSAGE
        picture.filename = Sudoku.data_path("illustrations", PICTURE)
      end
  end
end
