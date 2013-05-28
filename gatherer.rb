require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require 'optparse'
require 'ostruct'
require 'tempfile'

require_relative 'card_set'
require_relative 'card'

class Gatherer
  attr_accessor :sets, :agent, :options

  Usage =
  <<-eos
    Usage:
      ruby gatherer.rb [options]

    Options:
      -f, [--force]                # Ignore file collisions
      -o, [--only-sets]            # Only download set info
      -s, [--sets=SETS]            # Comma delimited list of sets to retrieve
      -S, [--skip]                 # Skip file collisions

      -p, [--pretend]              # Run but do not output any files
      -q, [--quiet]                # Supress status output
      -V, [--verbose]              # Show extra output
      -y, [--pry]                  # Pry after completing

      -h, [--help]                 # Show this help message and quit
      -v, [--version]              # Show gatherer.rb version number and quit

    Description:
      Scrapes gatherer.wizards.com for MTG sets and cards. Outputs the
      results as SQL files; one for the list of sets and then one for
      each set.

    Examples:
        ruby gatherer.rb
        This retrieves all MTG sets.

        ruby gatherer.rb -s "Alliances,Future Sight"
        This retrieves the "Alliances" and "Future Sight" sets.

        ruby gatherer.rb -oy
        This retrieves only the sets (no cards) and then opens a Pry debug session.
  eos

  Version = '0.2.1'

  def initialize
    @options = OpenStruct.new

    @options.force = false
    @options.sets = Array.new
    @options.only_sets = false
    @options.pretend = false
    @options.quiet = false
    @options.verbose = false
    @options.debug_with_pry = false
    @options.help = false
    @options.version = false

    @sets = Array.new

    @agent = Mechanize.new
  end

  def parse_options(argv)
    begin
      op = OptionParser.new do |ops|
        ops.banner = Usage
        ops.separator('')

        ops.on('-f', '--force', 'Ignore file collisions') do |force|
          @options.force = force
        end

        ops.on('-o', '--only-sets', 'Only download set info') do |only_sets|
          @options.only_sets = only_sets
        end

        ops.on('-s', '--sets SETS', 'Comma delimited list of sets to retrieve') do |sets|
          @options.sets = sets.split(',')
        end

        ops.on('-S', '--skip', 'Skip file collisions') do |skip|
          @options.skip = skip
        end

        ops.on('-p', '--pretend', 'Run but do not output any files') do |pretend|
          @options.pretend = pretend
        end

        ops.on('-q', '--quiet', 'Supress status output') do |quiet|
          @options.quiet = quiet
        end

        ops.on('-V', '--verbose', 'Show extra output') do |verbose|
          @options.verbose = verbose
        end

        ops.on('-y', '--pry', 'Pry after completing') do |debug_with_pry|
          @options.debug_with_pry = debug_with_pry
        end

        ops.on('-h', '--help', 'Show this help message and quit') do |help|
          puts Usage
          exit
        end

        ops.on('-v', '--version', 'Show gatherer.rb version number and quit') do |version|
          puts "gatherer.rb #{Version}"
          exit
        end
      end

      op.parse!(argv)
    rescue Exception => exception
      puts "Error: #{exception.message}\n\n"
      puts Usage
      exit
    end
  end

  def get_card_sets
    if @options.sets.present?
      set_names = @options.sets
    else
      search_page = @agent.get('http://gatherer.wizards.com/Pages/Default.aspx')

      set_names = search_page.parser.css('select#ctl00_ctl00_MainContent_Content_SearchControls_setAddText').children.map { |set_name| set_name.attributes['value'].present? ? set_name.attributes['value'].text : '' }
    end

    set_names.reject! { |set_name| set_name.blank? }

    set_names.each do |set_name|
      set = CardSet.new

      set.name = set_name.strip

      if set.name.present?
        @sets << set
      end
    end
  end

  def output_card_sets_list_as_sql
    write_file('output/sets.sql') do |file|
      @sets.each do |set|
        name = set.name.clone

        unless name.nil?
          name.gsub!(/'/, "''")
          name.strip!
        end

        file.puts "INSERT INTO CARD_SETS (name) VALUES ('#{name}');"
      end
    end
  end

  def output_card_sets_as_sql
    @sets.each do |set|
      output_card_set_as_sql(set)
    end
  end

  def output_card_set_as_sql(set)
    write_file("output/#{set.name.gsub(/'/, '').parameterize.underscore}.sql") do |file|
      set.cards.sort { |a, b| a.multiverse_id.to_i <=> b.multiverse_id.to_i }.each do |card|
        multiverse_id = card.multiverse_id

        if multiverse_id.present?
          multiverse_id = multiverse_id.gsub(/'/, "''").strip
        end

        name = card.name

        if name.present?
          name = name.gsub(/'/, "''").strip
        end

        mana_cost = card.mana_cost

        if mana_cost.present?
          mana_cost = mana_cost.gsub(/'/, "''").strip
        end

        converted_mana_cost = card.converted_mana_cost

        if converted_mana_cost.present?
          converted_mana_cost = converted_mana_cost.gsub(/'/, "''").strip
        end

        card_type = card.card_type

        if card_type.present?
          card_type = card_type.gsub(/'/, "''").strip
        end

        card_text = card.card_text

        if card_text.present?
          card_text = card_text.gsub(/'/, "''").strip
        end

        flavor_text = card.flavor_text

        if flavor_text.present?
          flavor_text = flavor_text.gsub(/'/, "''").strip
        end

        power = card.power

        if power.present?
          power = power.gsub(/'/, "''").strip
        end

        toughness = card.toughness

        if toughness.present?
          toughness = toughness.gsub(/'/, "''").strip
        end

        loyalty = card.loyalty

        if loyalty.present?
          loyalty = loyalty.gsub(/'/, "''").strip
        end

        rarity = card.rarity

        if rarity.present?
          rarity = rarity.gsub(/'/, "''").strip
        end

        card_number = card.card_number

        if card_number.present?
          card_number = card_number.gsub(/'/, "''").strip
        end

        artist = card.artist

        if artist.present?
          artist = artist.gsub(/'/, "''").strip
        end

        file.puts "INSERT INTO CARDS (multiverse_id, name, mana_cost, converted_mana_cost, card_type, card_text, flavor_text, power, toughness, loyalty, rarity, card_number, artist) VALUES ('#{multiverse_id}', '#{name}', '#{mana_cost}', '#{converted_mana_cost}', '#{card_type}', '#{card_text}', '#{flavor_text}', '#{power}', '#{toughness}', '#{loyalty}', '#{rarity}', '#{card_number}', '#{artist}');"
      end
    end
  end

  def get_cards
    @sets.each do |set|
      set_page_uri = "http://gatherer.wizards.com/Pages/Search/Default.aspx?sort=color+&set=[%22#{CGI::escape(set.name)}%22]"

      begin
        set_page = agent.get(set_page_uri)

        card_containers = set_page.parser.css('.cardItem')

        card_containers.each do |card_container|
          card_links = card_container.css('.cardTitle a')

          card_links.each do |card_link|
            card = get_card("http://gatherer.wizards.com/Pages/#{card_link.attributes['href'].text[3, (card_link.attributes['href'].text.length - 3)]}")

            set.cards << card
          end

          other_version_links = card_container.css('.setVersions .otherSetSection a')

          other_version_links.each do |other_version_link|
            if other_version_link.css('img').length > 0
              if other_version_link.css('img')[0].attribute('alt').value.match(set.name)
                other_version = get_card("http://gatherer.wizards.com/Pages/#{other_version_link.attributes['href'].text[3, (other_version_link.attributes['href'].text.length - 3)]}")

                set.cards << other_version
              end
            end
          end
        end

        next_page_uri = ''

        if set_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_topPagingControlsContainer a").length > 0
          pagination_links = set_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_topPagingControlsContainer a")

          pagination_links.each do |pagination_link|
            if pagination_link.children[0].text[-1].strip == '>'
              next_page_uri = "http://gatherer.wizards.com#{pagination_link.attributes['href'].text}"

              break
            end
          end
        end

        if next_page_uri != set_page_uri && next_page_uri.present?
          set_page_uri = next_page_uri
        else
          set_page_uri = ''
        end
      end while set_page_uri != ''
    end
  end

  def get_card(card_page_uri)
    card_page = agent.get(card_page_uri)

    card = Card.new

    if card_page.parser.css("#aspnetForm").length > 0
      multiverse_id = card_page.parser.css("#aspnetForm").attribute("action").text

      card.multiverse_id = multiverse_id[multiverse_id.index('=') + 1..-1]
    else
      card.multiverse_id = ''
    end

    if card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_nameRow .value").length > 0
      card.name = card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_nameRow .value").text.strip
    else
      card.name = ''
    end

    if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_manaRow .value img').length > 0
      mana_cost = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_manaRow .value img')

      mana = Array.new

      mana_cost.each do |mc|
        mana << mc.attributes['alt'].text
      end

      card.mana_cost = mana.join(';')
    else
      card.mana_cost = ''
    end

    if card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_cmcRow .value").length > 0
      card.converted_mana_cost = card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_cmcRow .value").text.strip
    else
      card.converted_mana_cost = ''
    end

    if card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_typeRow .value").length > 0
      card.card_type = PP.pp(card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_typeRow .value").text.strip, '')

      card.card_type = card.card_type.gsub(/\n/, '').gsub(/"/, '').gsub(/  \\342\\200\\224 /, " &mdash; ")
    else
      card.card_type = ''
    end

     if card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_textRow .value").length > 0
      card_text = card_page.parser.css("#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_textRow .value").children.to_s.strip

      card_text_doc = Nokogiri::HTML(card_text)

      card_text_doc.xpath("//img").each do |img|
        src = img['src']

        name = src.scan(/name=(.*)&/)

        img['src'] = "/assets/symbols/#{name[0][0]}.png"

        img.xpath('//@align').each(&:remove)
      end

      card_text_box = card_text_doc.xpath("//div[@class='cardtextbox']")

      card.card_text = card_text_box.inner_html.gsub(/\n/, "").gsub(/<i>/, "<em>").gsub(/<\/i>/, "</em>")
    else
      card.card_text = ''
    end

    if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_flavorRow .value').length > 0
      flavor_text = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_flavorRow .value').children.to_s.strip

      flavor_text_doc = Nokogiri::HTML(flavor_text)

      flavor_text_box = flavor_text_doc.xpath("//div[@class='cardtextbox']")

      card.flavor_text = flavor_text_box.inner_html.gsub(/<i>/, "<em>").gsub(/<\/i>/, "</em>")
    else
      card.flavor_text = ''
    end

    card.power = ''
    card.toughness = ''
    card.loyalty = ''

    if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow').length > 0
      if card.card_type =~ /Planeswalker/
        if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .label').length > 0
          if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .label').text.strip =~ /Loyalty:/
            if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .value').length > 0
              card.loyalty = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .value').text.strip
            end
          end
        end
      else
        if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .label').length > 0
          if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .label').text.strip =~ /P\/T:/
            if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .value').length > 0
              card.power = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .value').text.strip.split('/')[0].strip

              card.toughness = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow .value').text.strip.split('/')[1].strip
            end
          end
        end
      end
    end

    if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_rarityRow .value').length > 0
      card.rarity = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_rarityRow .value').text.strip
    else
      card.rarity = ''
    end

    if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_numberRow .value').length > 0
      card.card_number = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_numberRow .value').text.strip
    else
      card.card_number = ''
    end

    if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_artistRow .value').length > 0
      card.artist = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_artistRow .value').text.strip
    else
      card.artist = ''
    end

    set_name = ''

    if card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_currentSetSymbol a').length > 0
      set_name = card_page.parser.css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_currentSetSymbol a')[1].text.strip
    end

    if options.verbose
      puts "Retrieved card #{card.multiverse_id} \"#{card.name}\" #{set_name.present? ? "(#{set_name})" : ''}"
    end

    card
  end

  def run!
    self.parse_options(ARGV)

    self.get_card_sets

    self.output_card_sets_list_as_sql

    unless @options.only_sets
      self.get_cards

      self.output_card_sets_as_sql
    end

    if @options.debug_with_pry
      binding.of_caller(1).pry
    end
  end

  private

  def write_file(destination, &block)
    destination_exists = File.exist?(destination)

    tempfile = nil

    Tempfile.open(File.basename(destination)) do |temp|
      yield temp

      tempfile = temp
    end

    if destination_exists && identical?(tempfile.path, destination)
      puts "#{destination} is identical, ignoring."

      return false
    end

    if destination_exists
      if @options.skip
        puts "#{destination} exists, skipping."

        return false
      end

      if @options.force
        File.open(destination, 'w') do |file|
          yield file
        end

        return true
      end

      begin
        puts "Warning: \"#{destination} already exists. Force overwrite? (enter \"h\" for help) [ynaqdh]"

        case gets.chomp
        when /\Ay\z/i
          puts "Overwriting #{destination}."

          File.open(destination, 'w') do |file|
            yield file
          end

          return true
        when /\An\z/i
          puts "Skipping #{destination}."

          return false
        when /\Aa\z/i
          @options.force = true

          File.open(destination, 'w') do |file|
            yield file
          end

          return true
        when /\Aq\z/i
          puts "Skipping #{destination} and exiting."

          exit
        when /\Ad\z/i
          Tempfile.open(File.basename(destination), File.dirname(destination)) do |temp|
            temp.write IO.read(tempfile.path)

            temp.rewind

            puts
            puts `diff -u #{destination} #{temp.path}`
            puts
          end

          raise 'retry diff'
        else
          puts <<-HELP
                    y - yes, overwrite
                    n - no, do not overwrite
                    a - all, overwrite this and all others
                    q - quit, abort
                    d - diff, show the differences between the old and the new
                    h - help, show this help
                  HELP

          raise 'retry help'
        end
      rescue
        retry
      end
    else
      File.open(destination, 'w') do |file|
        yield file
      end

      true
    end
  end

  def identical?(source, destination)
    return false if File.directory?(destination)

    source      = IO.read(source)

    destination = IO.read(destination)

    source == destination
  end
end

gatherer = Gatherer.new

gatherer.run!
