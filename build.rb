#!/usr/bin/env ruby

require 'pry'

require 'cgi'
require 'csv'
require 'json'
require 'open-uri'

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

    RepeatedCardError = Class.new(StandardError)

    attr_reader :title, :description, :decks

    def initialize(title:, description:, decks:)
      @title = title
      @description = description
      @decks = decks
    end

    def overview
      validate!

      [
        h2(title),
        hr,
        description,
        h2('Archetypes and inspiration'),
        hr,
        *decks.map(&:overview),
      ].join("\n\n")
    end

    def validate!
      decks.flat_map(&:cards).sort.tally.each do |card, count|
        if count > 1
          raise RepeatedCardError, "#{card} is used as the image for #{count} decks"
        end
      end
    end
  end

  class Deck
    include Markdown

    attr_reader :title, :mana, :stars, :cards, :cube_cobra, :scryfall

    def initialize(title:, mana:, stars:, cards:)
      @title = title
      @mana = mana
      @stars = stars
      @cards = cards
      @cube_cobra = CubeCobra.new
      @scryfall = Scryfall.new
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
      cards.map do |card_name|
        cube_cobra_card_data = cube_cobra.card_by_name(card_name)

        set = cube_cobra_card_data['Set']
        collector_number = cube_cobra_card_data['Collector Number']
        collector_number.gsub!(/\D/, '') # PLIST "XLN-1" => "1"

        scryfall_card_data = scryfall.find_card_by("!#{card_name.inspect} s:#{set} cn:#{collector_number}")

        "<<[[!#{card_name}|#{scryfall_card_data[:id]}]]>>"
      end.join('')
    end
  end

  class CubeCobra
    CardNotFoundError = Class.new(StandardError)

    def card_by_name(name)
      result = cards.find { |card| card['name'] == name }

      result || raise(CardNotFoundError, "Found no card in cube called #{name.inspect}")
    end

    def cards
      @cards ||= CSV.parse(csv, headers: true).map(&:to_h)
    end

    def csv
      URI.open(url).read
    end

    def url
      'https://cubecobra.com/cube/download/csv/5ec423906c26474a6ce5eb85?primary=Color%20Category&secondary=Types-Multicolor&tertiary=Mana%20Value&quaternary=Alphabetical&showother=false'
    end
  end

  class Scryfall
    TooManyCardsError = Class.new(StandardError)
    CardNotFoundError = Class.new(StandardError)

    def find_card_by(search)
      json = URI.open("https://api.scryfall.com/cards/search?q=#{CGI.escape(search)}").read
      data = JSON.parse(json, symbolize_names: true)

      if data[:data].count == 1
        data[:data][0]
      elsif data[:data].count > 1
        raise TooManyCardsError, "Found #{data[:data].count} cards for search #{search.inspect}"
      else
        raise CardNotFoundError, "Found no cards for search #{search.inspect}"
      end
    end
  end
end

ob = CubeCobra::OverviewBuilder.new(
  title: 'My 360 card cube',
  description: "My goal is to have a legacy power level cube with no old frame cards that is accessible to newer players.\nAll cards must be English, modern frame, and non-foil. As a happy coincidence that also means it has no cards from the reserved list.\nMy playgroup includes people I've taught to play in the last few years, so I've tried to exclude cards that might be confusing during drafting and playing. To that end, I've cut a bunch of mechanics entirely: storm, morph, level up, etc. Originally I excluded all double-faced cards but I've decided to include the Magic Origins planeswalkers because I love Jace, Vryn's Prodigy.",
  decks: [
    CubeCobra::Deck.new(title: 'Monowhite Aggro', mana: 'w', stars: 5, cards: ['Isamaru, Hound of Konda', 'Stoneforge Mystic', 'Adanto Vanguard']),
    CubeCobra::Deck.new(title: 'Monoblue Control', mana: 'u', stars: 3, cards: ['Jace, the Mind Sculptor', 'Counterspell', 'Cryptic Command']),
    CubeCobra::Deck.new(title: 'Monoblack Aggro', mana: 'b', stars: 3, cards: ['Knight of the Ebon Legion', 'Graf Reaver', 'Thoughtseize']),
    CubeCobra::Deck.new(title: 'Monored Aggro', mana: 'r', stars: 5, cards: ['Goblin Guide', 'Chain Lightning', 'Sulfuric Vortex']),
    CubeCobra::Deck.new(title: 'Monogreen Ramp', mana: 'g', stars: 4, cards: ['Fyndhorn Elves', 'Oracle of Mul Daya', 'Primeval Titan']),
    CubeCobra::Deck.new(title: 'Azorius Control', mana: 'wu', stars: 4, cards: ['Swords to Plowshares', 'Mana Leak', 'Teferi, Time Raveler']),
    CubeCobra::Deck.new(title: 'Dimir Reanimator', mana: 'ub', stars: 5, cards: ["Jace, Vryn's Prodigy", 'Animate Dead', 'Griselbrand']),
    CubeCobra::Deck.new(title: 'Dimir Aggro Control', mana: 'ub', stars: 4, cards: ['Snapcaster Mage', 'Dauthi Voidwalker', 'Baleful Strix']),
    CubeCobra::Deck.new(title: 'Rakdos Aggro Control', mana: 'br', stars: 3, cards: ['Kitesail Freebooter', 'Ragavan, Nimble Pilferer', 'Alesha, Who Laughs at Fate']),
    CubeCobra::Deck.new(title: 'Gruul Midrange', mana: 'rg', stars: 2, cards: ['Flametongue Kavu', "Esika's Chariot", 'Bloodbraid Elf']),
    CubeCobra::Deck.new(title: 'Gruul Lands', mana: 'rg', stars: 3, cards: ['Ramunap Excavator', 'Titania, Protector of Argoth', 'Wrenn and Six']),
    CubeCobra::Deck.new(title: 'Selesnya Ramp', mana: 'gw', stars: 1, cards: ['Timeless Dragon', 'Fanatic of Rhonas', "Mirari's Wake"]),
    CubeCobra::Deck.new(title: 'Orzhov Control', mana: 'wb', stars: 2, cards: ['Wrath of God', 'Damnation', 'Vindicate']),
    CubeCobra::Deck.new(title: 'Orzhov Tokens', mana: 'wb', stars: 3, cards: ['Lingering Souls', 'Bitterblossom', 'Intangible Virtue']),
    CubeCobra::Deck.new(title: 'Izzet Control', mana: 'ur', stars: 3, cards: ['Glen Elendra Archmage', 'Anger of the Gods', 'Electrolyze']),
    CubeCobra::Deck.new(title: 'Izzet Artifacts', mana: 'ur', stars: 4, cards: ['Urza, Lord High Artificer', 'Goblin Welder', 'Myr Battlesphere']),
    CubeCobra::Deck.new(title: 'Izzet Twin', mana: 'ur', stars: 4, cards: ['Pestermite', 'Kiki-Jiki, Mirror Breaker', 'Expressive Iteration']),
    CubeCobra::Deck.new(title: 'Golgari Reanimator', mana: 'bg', stars: 3, cards: ['Archon of Cruelty', 'Fauna Shaman', 'Meren of Clan Nel Toth']),
    CubeCobra::Deck.new(title: 'Golgari Ramp', mana: 'bg', stars: 3, cards: ['Veteran Explorer', 'Cabal Therapy', 'Flare of Cultivation']),
    CubeCobra::Deck.new(title: 'Boros Aggro', mana: 'rw', stars: 3, cards: ['Mother of Runes', 'Robber of the Rich', "Otharri, Suns' Glory"]),
    CubeCobra::Deck.new(title: 'Simic Ramp', mana: 'gu', stars: 5, cards: ['Mana Drain', 'Birds of Paradise', 'Hydroid Krasis']),
    CubeCobra::Deck.new(title: 'Bant Control', mana: 'gwu', stars: 1, cards: ['Noble Hierarch', 'Loran of the Third Path', 'Consecrated Sphinx']),
    CubeCobra::Deck.new(title: 'Esper Control', mana: 'wub', stars: 3, cards: ['Day of Judgment', 'Fact or Fiction', 'Toxic Deluge']),
    CubeCobra::Deck.new(title: 'Esper Reanimator', mana: 'wub', stars: 3, cards: ['Elesh Norn, Grand Cenobite', 'Looter il-Kor', 'Grave Titan']),
    CubeCobra::Deck.new(title: 'Grixis Reanimator', mana: 'ubr', stars: 3, cards: ['Chart a Course', 'Exhume', 'Glorybringer']),
    CubeCobra::Deck.new(title: 'Grixis Twin', mana: 'ubr', stars: 3, cards: ['Deceiver Exarch', 'Demonic Tutor', 'Splinter Twin']),
    CubeCobra::Deck.new(title: 'Jund', mana: 'brg', stars: 2, cards: ['Dark Confidant', 'Lightning Bolt', 'Tarmogoyf']),
    CubeCobra::Deck.new(title: 'Naya Ramp', mana: 'rgw', stars: 2, cards: ['Chandra, Torch of Defiance', 'Nissa, Who Shakes the World', "Elspeth, Sun's Champion"]),
    CubeCobra::Deck.new(title: 'Abzan Reanimator', mana: 'wbg', stars: 1, cards: ['Sun Titan', 'Collective Brutality', 'Terastodon']),
    CubeCobra::Deck.new(title: 'Jeskai Control', mana: 'urw', stars: 3, cards: ['Riftwing Cloudskate', 'Rolling Earthquake', 'Path to Exile']),
    CubeCobra::Deck.new(title: 'Jeskai Twin', mana: 'urw', stars: 5, cards: ['Dig Through Time', 'Zealous Conscripts', 'Restoration Angel']),
    CubeCobra::Deck.new(title: 'Sultai Midrange', mana: 'bgu', stars: 3, cards: ['Tasigur, the Golden Fang', 'Sylvan Library', 'Time Warp']),
    CubeCobra::Deck.new(title: 'Mardu Control', mana: 'rwb', stars: 1, cards: ['Fiery Confluence', 'Balance', 'Crabomination']),
    CubeCobra::Deck.new(title: 'Temur Twin', mana: 'gur', stars: 2, cards: ['Birthing Pod', 'Impulse', 'Imperial Recruiter']),
    CubeCobra::Deck.new(title: 'Temur Midrange', mana: 'gur', stars: 4, cards: ['Sakura-Tribe Elder', 'Minsc & Boo, Timeless Heroes', 'Oko, Thief of Crowns']),
    CubeCobra::Deck.new(title: '5 Color Control', mana: 'wubrg', stars: 3, cards: ['Golos, Tireless Pilgrim', 'Coalition Relic', 'City of Brass']),
  ],
)

puts ob.overview
