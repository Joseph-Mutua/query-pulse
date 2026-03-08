module Parsers
  module SearchPage
    class RelatedQuestionsParser
      SELECTORS = ["[data-related-question]", ".related-question", ".people-also-ask button"].freeze

      def self.call(html)
        document = Nokogiri::HTML5(html.to_s)
        nodes = SELECTORS.lazy.map { |selector| document.css(selector) }.find(&:any?) || []
        nodes.map { |node| node.text.squish }.reject(&:blank?).uniq
      rescue Nokogiri::SyntaxError
        []
      end
    end
  end
end
