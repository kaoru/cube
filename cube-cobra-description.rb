#!/usr/bin/env ruby

require 'debug'

require 'cgi'
require 'csv'
require 'json'
require 'open-uri'
require 'digest'

class CubeCobra
  module UrlFetcher
    def fetch_url_response(url)
      if cached?(url)
        read_cache(url)
      else
        response = URI.open(url).read
        write_cache(url, response)
        response
      end
    end

    private

    def cached?(url)
      File.file?(cache_file_for_url(url))
    end

    def read_cache(url)
      File.open(cache_file_for_url(url)).read
    end

    def write_cache(url, response)
      File.write(cache_file_for_url(url), response)
    end

    def cache_file_for_url(url)
      [__dir__, '.cache', Digest::SHA512.hexdigest(url)].join('/')
    end
  end

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
        h3("#{mana_symbols} #{title} #{'⭐' * stars}"),
        card_images
      ].join("\n")
    end

    def mana_symbols
      mana.chars.map { |m| "{#{m}}" }.join
    end

    def card_images
      images = cards.map do |card_name|
        cube_cobra_card_data = cube_cobra.card_by_name(card_name)

        set = cube_cobra_card_data['Set']
        collector_number = cube_cobra_card_data['Collector Number']
        collector_number.gsub!(/\D/, '') # PLIST "XLN-1" => "1"

        scryfall_card_data = scryfall.find_card_by("!#{card_name.inspect} s:#{set} cn:#{collector_number}")

        "[[!#{card_name}|#{scryfall_card_data[:id]}]]"
      end

      "<<#{images.join}>>"
    end
  end

  class CubeCobra
    include UrlFetcher

    CardNotFoundError = Class.new(StandardError)

    def card_by_name(name)
      result = cards.find { |card| card['name'] == name }

      result || raise(CardNotFoundError, "Found no card in cube called #{name.inspect}")
    end

    def cards
      @cards ||= CSV.parse(csv, headers: true).map(&:to_h)
    end

    def csv
      fetch_url_response(url)
    end

    def url
      'https://cubecobra.com/cube/download/csv/5ec423906c26474a6ce5eb85?primary=Color%20Category&secondary=Types-Multicolor&tertiary=Mana%20Value&quaternary=Alphabetical&showother=false'
    end
  end

  class Scryfall
    include UrlFetcher

    TooManyCardsError = Class.new(StandardError)
    CardNotFoundError = Class.new(StandardError)

    def find_card_by(search)
      json = fetch_url_response("https://api.scryfall.com/cards/search?q=#{CGI.escape(search)}")
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
  title: 'The kaokun cube',
  description: "The goal for this cube is to have a high power cube that’s highly accessible to newer players. It should be a great first cube draft experience for someone who’s played some Magic and maybe watched LSV cube draft once or twice on YouTube, and wants to give it a go themselves.\n\nTo aid accessibility, all cards must be English, non-foil, with an M15 frame and correct Oracle text where possible. I also prefer a traditional high fantasy art aethsetic where possible. As a happy coincidence the M15 frame requirement also means the cube has no cards from the reserved list.\n\nMy playgroup includes people I've taught to play in the last few years, so I've tried to exclude cards that might be confusing during drafting and playing. To that end, I've banned a number of mechanics entirely: storm, morph, level up, initiative, etc. Originally I excluded all double-faced cards but I've decided to include the Magic Origins planeswalkers because I love Jace, Vryn's Prodigy.\n\nI don’t ascribe to a “10 two color archetypes” model of cube design. The list of archetypes below is intended to be evidence of the wide range of decks available even within the same color combinations, and is not an exhaustive list.",
  decks: [
    CubeCobra::Deck.new(title: 'Monowhite Aggro', mana: 'w', stars: 5, cards: ['Isamaru, Hound of Konda', 'Stoneforge Mystic', 'Adanto Vanguard']),
    CubeCobra::Deck.new(title: 'Monoblue Control', mana: 'u', stars: 3, cards: ['Jace, the Mind Sculptor', 'Counterspell', 'Cryptic Command']),
    CubeCobra::Deck.new(title: 'Monoblack Aggro', mana: 'b', stars: 3, cards: ['Knight of the Ebon Legion', 'Emperor of Bones', 'Thoughtseize']),
    CubeCobra::Deck.new(title: 'Monored Aggro', mana: 'r', stars: 5, cards: ['Goblin Guide', 'Chain Lightning', 'Fireblast']),
    CubeCobra::Deck.new(title: 'Monogreen Stompy', mana: 'g', stars: 4, cards: ['Fyndhorn Elves', 'Ursine Monstrosity', 'Six']),
    CubeCobra::Deck.new(title: 'Azorius Control', mana: 'wu', stars: 4, cards: ['Swords to Plowshares', 'Force of Will', 'Teferi, Time Raveler']),
    CubeCobra::Deck.new(title: 'Dimir Reanimator', mana: 'ub', stars: 5, cards: ["Jace, Vryn's Prodigy", 'Animate Dead', 'Griselbrand']),
    CubeCobra::Deck.new(title: 'Dimir Aggro Control', mana: 'ub', stars: 4, cards: ['Snapcaster Mage', 'Dauthi Voidwalker', 'Baleful Strix']),
    CubeCobra::Deck.new(title: 'Dimir Control', mana: 'ub', stars: 3, cards: ['Damnation', 'Preordain', "Night's Whisper"]),
    CubeCobra::Deck.new(title: 'Rakdos Aggro Control', mana: 'br', stars: 3, cards: ['Deep-Cavern Bat', 'Ragavan, Nimble Pilferer', 'Alesha, Who Laughs at Fate']),
    CubeCobra::Deck.new(title: 'Rakdos Sneak Attack', mana: 'br', stars: 3, cards: ['Sneak Attack', 'Kokusho, the Evening Star', 'Ulamog, the Infinite Gyre']),
    CubeCobra::Deck.new(title: 'Gruul Midrange', mana: 'rg', stars: 4, cards: ['Pyrogoyf', "Esika's Chariot", 'Bloodbraid Elf']),
    CubeCobra::Deck.new(title: 'Gruul Lands', mana: 'rg', stars: 3, cards: ['Orcish Lumberjack', 'Titania, Protector of Argoth', 'Wrenn and Six']),
    CubeCobra::Deck.new(title: 'Selesnya Ramp', mana: 'gw', stars: 1, cards: ["Elspeth, Sun's Champion", 'Fanatic of Rhonas', "Mirari's Wake"]),
    CubeCobra::Deck.new(title: 'Orzhov Control', mana: 'wb', stars: 2, cards: ['Austere Command', 'Necropotence', 'Lingering Souls']),
    CubeCobra::Deck.new(title: 'Orzhov Tokens', mana: 'wb', stars: 3, cards: ['Shadow Summoning', 'Bitterblossom', 'Intangible Virtue']),
    CubeCobra::Deck.new(title: 'Izzet Control', mana: 'ur', stars: 3, cards: ['Remand', 'Kari Zev, Skyship Raider', 'Electrolyze']),
    CubeCobra::Deck.new(title: 'Izzet Artifacts', mana: 'ur', stars: 4, cards: ['Urza, Lord High Artificer', 'Goblin Welder', 'Kappa Cannoneer']),
    CubeCobra::Deck.new(title: 'Izzet Twin', mana: 'ur', stars: 4, cards: ['Pestermite', 'Kiki-Jiki, Mirror Breaker', 'Expressive Iteration']),
    CubeCobra::Deck.new(title: 'Golgari Reanimator', mana: 'bg', stars: 3, cards: ['Archon of Cruelty', 'Fauna Shaman', 'Meren of Clan Nel Toth']),
    CubeCobra::Deck.new(title: 'Golgari Ramp', mana: 'bg', stars: 3, cards: ['Veteran Explorer', 'Cabal Therapy', 'Flare of Cultivation']),
    CubeCobra::Deck.new(title: 'Boros Aggro', mana: 'rw', stars: 4, cards: ['Mother of Runes', 'Robber of the Rich', "Otharri, Suns' Glory"]),
    CubeCobra::Deck.new(title: 'Simic Ramp', mana: 'gu', stars: 5, cards: ['Mana Drain', 'Nissa, Who Shakes the World', 'Hydroid Krasis']),
    CubeCobra::Deck.new(title: 'Simic Nadu', mana: 'gu', stars: 5, cards: ['Nadu, Winged Wisdom', 'Lightning Greaves', 'Springheart Nantuko']),
    CubeCobra::Deck.new(title: 'Bant Control', mana: 'gwu', stars: 1, cards: ['Noble Hierarch', 'Loran of the Third Path', 'Consecrated Sphinx']),
    CubeCobra::Deck.new(title: 'Esper Control', mana: 'wub', stars: 3, cards: ['Day of Judgment', 'Fact or Fiction', 'Toxic Deluge']),
    CubeCobra::Deck.new(title: 'Esper Reanimator', mana: 'wub', stars: 3, cards: ['Elesh Norn, Grand Cenobite', 'Looter il-Kor', 'Grave Titan']),
    CubeCobra::Deck.new(title: 'Grixis Reanimator', mana: 'ubr', stars: 3, cards: ['Chart a Course', 'Exhume', 'Glorybringer']),
    CubeCobra::Deck.new(title: 'Grixis Twin', mana: 'ubr', stars: 3, cards: ['Deceiver Exarch', 'Demonic Tutor', 'Splinter Twin']),
    CubeCobra::Deck.new(title: 'Jund', mana: 'brg', stars: 3, cards: ['Dark Confidant', 'Lightning Bolt', 'Tarmogoyf']),
    CubeCobra::Deck.new(title: 'Naya Ramp', mana: 'rgw', stars: 1, cards: ['Palace Jailer', 'Ancient Grudge', 'Avenger of Zendikar']),
    CubeCobra::Deck.new(title: 'Abzan Midrange', mana: 'wbg', stars: 2, cards: ['Knight of Autumn', 'Vindicate', 'Grist, the Hunger Tide']),
    CubeCobra::Deck.new(title: 'Jeskai Control', mana: 'urw', stars: 3, cards: ['Occult Epiphany', 'Unholy Heat', 'Path to Exile']),
    CubeCobra::Deck.new(title: 'Jeskai Twin', mana: 'urw', stars: 4, cards: ['Dig Through Time', 'Zealous Conscripts', 'Restoration Angel']),
    CubeCobra::Deck.new(title: 'Sultai Midrange', mana: 'bgu', stars: 3, cards: ['Tasigur, the Golden Fang', 'Sylvan Library', 'Ponder']),
    CubeCobra::Deck.new(title: 'Mardu Control', mana: 'rwb', stars: 1, cards: ['Fiery Confluence', 'Balance', 'Crabomination']),
    CubeCobra::Deck.new(title: 'Temur Twin', mana: 'gur', stars: 2, cards: ['Birthing Pod', 'Mana Leak', 'Imperial Recruiter']),
    CubeCobra::Deck.new(title: 'Temur Midrange', mana: 'gur', stars: 4, cards: ['Sakura-Tribe Elder', 'Minsc & Boo, Timeless Heroes', 'Oko, Thief of Crowns']),
    CubeCobra::Deck.new(title: '5 Color Domain', mana: 'wubrg', stars: 3, cards: ['Leyline Binding', 'Nishoba Brawler', 'Territorial Kavu']),
    CubeCobra::Deck.new(title: '5 Color Control', mana: 'wubrg', stars: 3, cards: ['Golos, Tireless Pilgrim', 'Coalition Relic', 'City of Brass']),
  ],
)

puts ob.overview
