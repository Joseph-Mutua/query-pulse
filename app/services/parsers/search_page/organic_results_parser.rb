require "uri"

module Parsers
  module SearchPage
    class OrganicResultsParser
      RESULT_SELECTORS = ["[data-organic-result]", ".organic-result", "article.search-result"].freeze
      TITLE_SELECTORS = ["[data-result-title]", "h3", ".result-title"].freeze
      LINK_SELECTORS = ["a[data-result-link]", "h3 a", "a.result-link", "a[href]"].freeze
      SNIPPET_SELECTORS = ["[data-result-snippet]", ".snippet", ".result-snippet"].freeze
      DISPLAYED_LINK_SELECTORS = ["[data-displayed-url]", ".displayed-url", "cite"].freeze

      def self.call(html)
        new(html).call
      end

      def initialize(html)
        @document = Nokogiri::HTML5(html.to_s)
      end

      def call
        nodes.each_with_index.filter_map do |node, index|
          link_node = first_match(node, LINK_SELECTORS)
          title = text_of(first_match(node, TITLE_SELECTORS))
          url = link_node&.[]("href").to_s
          next if title.blank? || url.blank?

          {
            "position" => node["data-position"].to_i.nonzero? || index + 1,
            "title" => title,
            "url" => url,
            "displayed_url" => text_of(first_match(node, DISPLAYED_LINK_SELECTORS)).presence || safe_host(url),
            "snippet" => text_of(first_match(node, SNIPPET_SELECTORS)).presence
          }.compact
        end
      rescue Nokogiri::SyntaxError
        []
      end

      private

      def nodes
        RESULT_SELECTORS.lazy.map { |selector| @document.css(selector) }.find(&:any?) || []
      end

      def first_match(node, selectors)
        selectors.lazy.map { |selector| node.at_css(selector) }.find(&:present?)
      end

      def text_of(node)
        node&.text.to_s.squish
      end

      def safe_host(url)
        URI.parse(url).host.to_s
      rescue URI::InvalidURIError
        ""
      end
    end
  end
end
