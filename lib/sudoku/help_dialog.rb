# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "translations"

module Sudoku
  # Ported from upstream src/screens/help_dialog.py and
  # data/blueprints/how-to-play-dialog.blp.
  #
  # The How To Play dialog: a carousel of illustrated pages with dots in the
  # header, previous/next buttons overlaid on the sides, and left/right keys
  # bound to the same moves (swapped in a right-to-left layout).
  class HowToPlayDialog < Adwaita::Dialog
    type_register
    include Gettext

    PAGES = [
      [
        "basics.svg",
        _("The Basics"),
        _(
          "The board is a 9×9 grid, divided into nine 3×3 blocks. " \
            "Fill every cell with numbers from 1 to 9.",
        ),
      ],
      [
        "rows-and-columns.svg",
        _("Rows & Columns"),
        _("Each row and column must contain unique numbers without duplicates."),
      ],
      [
        "blocks.svg",
        _("Blocks Matter"),
        _("Each 3×3 block must also contain the numbers 1 through 9, without repeats."),
      ],
      [
        "casual.svg",
        _("Casual Mode"),
        _(
          "Turn on Casual Mode in Preferences to check your entries against the " \
            "solution. When off, only rule violations are flagged, not incorrect numbers.",
        ),
      ],
      [
        "mistake.svg",
        _("Mistakes Happen"),
        _("Mistakes are highlighted in red so you can spot them easily."),
      ],
      [
        "pencil-mode.svg",
        _("Make Notes"),
        _("Use pencil mode to note possible numbers for a cell."),
      ],
    ].freeze

    def initialize
      super()
      build
    end

    def build
      tap do |dialog|
        dialog.content_width = 600
        dialog.content_height = 500
        dialog.add_css_class("how-to-play-dialog")
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = overlay

          header_bar.title_widget = indicator_dots

          overlay.tap do |stack|
            stack.child = clamp
            stack.add_overlay(previous_button)
            stack.add_overlay(next_button)

            clamp.child = carousel_box
            carousel_box.append(carousel)

            carousel.tap do |pages|
              PAGES.each { |(illustration, title, description)| pages.append(page(illustration, title, description)) }
            end
          end
        end

        previous_button.signal_connect("clicked") { show_previous }
        next_button.signal_connect("clicked") { show_next }
        carousel.signal_connect("page-changed") { update_button_sensitivity }
        dialog.add_controller(key_controller)
        update_button_sensitivity
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def overlay = @overlay ||= Gtk::Overlay.new

    def indicator_dots
      @indicator_dots ||= Adwaita::CarouselIndicatorDots.new.tap do |dots|
        dots.carousel = carousel
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |area|
        area.maximum_size = 600
        area.tightening_threshold = 400
      end
    end

    def carousel_box
      @carousel_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
        box.vexpand = true
      end
    end

    def carousel
      @carousel ||= Adwaita::Carousel.new.tap do |pages|
        pages.allow_long_swipes = true
        pages.allow_scroll_wheel = true
        pages.spacing = 40
      end
    end

    def previous_button
      @previous_button ||= Gtk::Button.new.tap do |button|
        button.halign = :start
        button.valign = :center
        button.margin_start = 16
        button.can_focus = true
        button.icon_name = "go-previous-symbolic"
        button.tooltip_text = _("Previous")
        button.sensitive = false
        button.add_css_class("circular")
      end
    end

    def next_button
      @next_button ||= Gtk::Button.new.tap do |button|
        button.halign = :end
        button.valign = :center
        button.margin_end = 16
        button.can_focus = true
        button.icon_name = "go-next-symbolic"
        button.tooltip_text = _("Next")
        button.add_css_class("circular")
      end
    end

    def key_controller
      @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
        controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, _state|
          on_key_pressed(keyval)
        end
      end
    end

    private

      def page(illustration, title, description)
        Gtk::Box.new(:vertical, 0).tap do |box|
          box.hexpand = true
          box.vexpand = true
          box.append(illustration_frame(illustration))
          box.append(status_page(title, description))
        end
      end

      def illustration_frame(illustration)
        Gtk::AspectFrame.new(
          0.5,
          0.5,
          1.0,
          false,
        ).tap do |frame|
          frame.halign = :center
          frame.valign = :center
          frame.hexpand = true
          frame.vexpand = true
          frame.child = illustration_picture(illustration)
        end
      end

      def illustration_picture(illustration)
        Gtk::Picture.new.tap do |picture|
          picture.filename = Sudoku.data_path("illustrations", illustration)
          picture.can_shrink = true
          picture.content_fit = :contain
        end
      end

      def status_page(title, description)
        Adwaita::StatusPage.new.tap do |status|
          status.title = title
          status.description = description
          status.can_focus = true
        end
      end

      def show_previous
        position = carousel.position.to_i
        if position.positive?
          carousel.scroll_to(carousel.get_nth_page(position - 1), true)
        end
      end

      def show_next
        position = carousel.position.to_i
        if position < carousel.n_pages - 1
          carousel.scroll_to(carousel.get_nth_page(position + 1), true)
        end
      end

      def update_button_sensitivity
        position = carousel.position
        previous_button.sensitive = position > 0
        next_button.sensitive = position < carousel.n_pages - 1
      end

      def on_key_pressed(keyval)
        rtl = direction == Gtk::TextDirection::RTL
        handled = true
        case keyval
        when Gdk::Keyval::KEY_Right
          step_forward(!rtl)
        when Gdk::Keyval::KEY_Left
          step_forward(rtl)
        else
          handled = false
        end
        handled
      end

      def step_forward(forward)
        if forward
          show_next
        else
          show_previous
        end
      end
  end
end
