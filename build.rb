#!/usr/bin/env ruby

class CubeCobra
  module Markdown
    def h3(str)
      "### #{str}"
    end

    def h2(str)
      "## #{str}"
    end

    def hr
      '-' * 30
    end
  end

  class OverviewBuilder
    include Markdown

    attr_reader :title, :description, :decks

    def initialize(title:, description:, decks:)
      @title = title
      @description = description
      @decks = decks
    end

    def overview
      [
        h2(title),
        hr,
        description,
        h2('Archetypes and inspiration'),
        hr,
        *decks.map(&:overview),
      ].join("\n\n")
    end
  end

  class Deck
    include Markdown

    attr_reader :title, :mana, :stars, :cards

    def initialize(title:, mana:, stars:, cards:)
      @title = title
      @mana = mana
      @stars = stars
      @cards = cards
    end

    def overview
      [
        h3("#{title} #{mana_symbols}"),
        '⭐' * stars,
        card_images
      ].join("\n\n")
    end

    def mana_symbols
      mana.chars.map { |m| "{#{m}}" }.join
    end

    def card_images
      "TODO"
    end
  end
end

ob = CubeCobra::OverviewBuilder.new(
  title: 'My 360 card cube',
  description: "My goal is to have a legacy power level cube with no old frame cards that is accessible to newer players.\nAll cards must be English, modern frame, and non-foil. As a happy coincidence that also means it has no cards from the reserved list.\nMy playgroup includes people I've taught to play in the last few years, so I've tried to exclude cards that might be confusing during drafting and playing. To that end, I've cut a bunch of mechanics entirely: storm, morph, level up, etc. Originally I excluded all double-faced cards but I've decided to include the Magic Origins planeswalkers because I love Jace, Vryn's Prodigy.",
  decks: [
    CubeCobra::Deck.new(title: 'Monowhite Aggro', mana: 'w', stars: 5, cards: ['Isamaru, Hound of Konda', 'Stoneforge Mystic', 'Adanto Vanguard'])
  ],
)

puts ob.overview
