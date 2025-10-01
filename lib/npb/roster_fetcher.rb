# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'
require 'time'

module Npb
  # Fetches player roster information from the NPB official site.
  class RosterFetcher
    class FetchError < StandardError; end

    BASE_URL = 'https://npb.jp/bis/teams/'
    INDEX_PAGES = %w[rst_c.html rst_p.html].freeze
    USER_AGENT = 'LineBotRoster/1.0 (+https://npb.jp)'
    CACHE_TTL = 30 * 60 # 30 minutes

    class << self
      def fetch
        if cached_data && cache_fresh?
          return cached_data
        end

        data = new.fetch_rosters
        cache_store(data)
        data
      rescue FetchError => e
        handle_fetch_error(e)
      end

      private

      def cache
        @cache ||= {}
      end

      def cached_data
        cache[:data]
      end

      def cache_fresh?
        cache[:stored_at] && (Time.now - cache[:stored_at] < CACHE_TTL)
      end

      def cache_store(data)
        cache[:data] = data
        cache[:stored_at] = Time.now
      end

      def handle_fetch_error(error)
        return cached_data.merge('stale' => true, 'error' => error.message) if cached_data

        raise error
      end
    end

    def fetch_rosters
      teams = INDEX_PAGES.flat_map { |page| extract_index(page) }
      {
        'fetched_at' => Time.now.utc.iso8601,
        'teams' => teams.compact
      }
    end

    private

    def extract_index(page)
      document = load_document(BASE_URL + page)
      roster_tables(document).filter_map do |table|
        team_name = detect_team_name(table)
        next unless team_name

        {
          'name' => team_name,
          'players' => extract_players(table)
        }
      end
    end

    def roster_tables(document)
      document.css('table').select do |table|
        header_cells = table.css('tr').first&.css('th,td')
        next false unless header_cells

        header_texts = header_cells.map { |cell| normalize_text(cell.text) }
        header_texts.any? { |text| text.include?('年齢') }
      end
    end

    def detect_team_name(table)
      heading = table.xpath('preceding-sibling::*[(self::h1 or self::h2 or self::h3 or self::h4 or self::h5)][1]').first
      heading && normalize_text(heading.text)
    end

    def extract_players(table)
      headers = table.css('tr').first.css('th,td').map { |cell| normalize_text(cell.text) }
      index_map = build_index_map(headers)

      table.css('tr')[1..]&.map do |row|
        cells = row.css('td')
        next if cells.empty?

        values = cells.map { |cell| normalize_text(cell.text) }
        age = pick_age(values, index_map[:age])
        next unless age

        player = {
          'number' => pick_value(values, index_map[:number]),
          'name' => pick_value(values, index_map[:name]),
          'position' => pick_value(values, index_map[:position]),
          'age' => age
        }

        handedness = pick_value(values, index_map[:handedness])
        player.merge!(parse_handedness(player['position'], handedness))
        player['handedness'] = handedness if handedness && !handedness.empty?
        player
      end.compact
    end

    def build_index_map(headers)
      {
        number: find_index(headers, %w[背番号 No. 番号]),
        name: find_index(headers, %w[選手名 氏名 名前 Name]),
        position: find_index(headers, %w[守備位置 守備 Pos ポジション]),
        age: find_index(headers, %w[年齢 年 Age]),
        handedness: find_index(headers, %w[投打 投/打 投・打 投/打ち])
      }
    end

    def find_index(headers, keywords)
      headers.index do |header|
        keywords.any? { |keyword| header.include?(keyword) }
      end
    end

    def pick_value(values, index)
      return nil unless index && index < values.length

      value = values[index]
      value unless value.nil? || value.empty?
    end

    def pick_age(values, index)
      raw = pick_value(values, index)
      return unless raw

      if raw =~ /(\d+)歳/
        Regexp.last_match(1).to_i
      elsif raw =~ /(\d+)/
        Regexp.last_match(1).to_i
      end
    end

    def parse_handedness(position, handedness)
      return {} unless handedness

      throw_hand = handedness[/([左右両])投/, 1]
      bat_hand = handedness[/([左右両])打/, 1]

      if position&.include?('投')
        { 'throws' => throw_hand }
      else
        data = {}
        data['throws'] = throw_hand if throw_hand
        data['bats'] = bat_hand if bat_hand
        data
      end
    end

    def load_document(url)
      html = URI.open(url, 'User-Agent' => USER_AGENT, 'Accept-Language' => 'ja-JP,ja;q=0.9,en-US;q=0.8').read
      Nokogiri::HTML.parse(html)
    rescue OpenURI::HTTPError, SocketError => e
      raise FetchError, "#{url} からデータを取得できませんでした: #{e.message}"
    rescue StandardError => e
      raise FetchError, "#{url} の解析に失敗しました: #{e.message}"
    end

    def normalize_text(text)
      text.to_s.gsub(/[\u00A0\u200B\t\r\n]+/, ' ').strip
    end
  end
end
