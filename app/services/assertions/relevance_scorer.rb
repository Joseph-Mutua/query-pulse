module Assertions
  class RelevanceScorer
    STOP_WORDS = %w[a an and for in is of on or the to with].freeze

    def self.call(data:, query:, assertions:, assertion_results: nil)
      new(data:, query:, assertions:, assertion_results:).call
    end

    def initialize(data:, query:, assertions:, assertion_results: nil)
      @data = data.to_h.deep_stringify_keys
      @query = query.to_s
      @assertions = assertions.to_h.deep_stringify_keys
      @assertion_results = assertion_results || Evaluator.call(data: @data, assertions: @assertions)
      @results = Array(@data["organic_results"])
    end

    def call
      components = {
        "query_coverage" => query_coverage_score,
        "expected_domains" => expected_domain_score,
        "title_expectations" => text_expectation_score("title_contains", "title", 20),
        "snippet_expectations" => text_expectation_score("snippet_contains", "snippet", 10),
        "assertion_health" => assertion_health_score
      }
      { "score" => components.values.sum.clamp(0, 100).round, "components" => components }
    end

    private

    def query_coverage_score
      tokens = tokenize(@query)
      return 40 if tokens.empty?

      corpus = @results.flat_map { |result| [result["title"], result["snippet"]] }.join(" ").downcase
      (tokens.count { |token| corpus.include?(token) }.fdiv(tokens.length) * 40).round(2)
    end

    def expected_domain_score
      expected = Array(@assertions["required_domains"])
      return 25 if expected.empty?

      domains = @results.map { |result| result["domain"].to_s }.reject(&:blank?)
      return 0 if domains.empty?

      matched = domains.count { |actual| expected.any? { |domain| actual == domain || actual.end_with?(".#{domain}") } }
      (matched.fdiv(domains.length) * 25).round(2)
    end

    def text_expectation_score(assertion, field, maximum)
      expected = Array(@assertions[assertion])
      return maximum if expected.empty?

      corpus = @results.map { |result| result[field].to_s.downcase }
      matched = expected.count { |term| corpus.any? { |text| text.include?(term.to_s.downcase) } }
      (matched.fdiv(expected.length) * maximum).round(2)
    end

    def assertion_health_score
      return 5 if @assertion_results.empty?

      (@assertion_results.count { |result| result["passed"] }.fdiv(@assertion_results.length) * 5).round(2)
    end

    def tokenize(text)
      text.downcase.scan(/[a-z0-9]+/).reject { |token| token.length < 2 || STOP_WORDS.include?(token) }.uniq
    end
  end
end
