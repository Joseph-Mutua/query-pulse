module Assertions
  class Evaluator
    SUPPORTED = %w[
      minimum_results maximum_results required_domains forbidden_domains title_contains
      snippet_contains maximum_response_time_ms required_fields
    ].freeze

    def self.call(data:, assertions:, response_time_ms: nil)
      new(data:, assertions:, response_time_ms:).call
    end

    def initialize(data:, assertions:, response_time_ms: nil)
      @data = data.to_h.deep_stringify_keys
      @assertions = assertions.to_h.deep_stringify_keys.slice(*SUPPORTED)
      @response_time_ms = response_time_ms || @data.dig("search_metadata", "response_time_ms")
      @results = Array(@data["organic_results"])
    end

    def call
      @assertions.map { |name, expected| send("evaluate_#{name}", expected) }
    end

    private

    def evaluate_minimum_results(expected)
      result("minimum_results", expected.to_i, @results.length, @results.length >= expected.to_i)
    end

    def evaluate_maximum_results(expected)
      result("maximum_results", expected.to_i, @results.length, @results.length <= expected.to_i)
    end

    def evaluate_required_domains(expected)
      expected = Array(expected).map { |domain| normalize_domain(domain) }
      actual = actual_domains
      missing = expected.reject { |domain| actual.any? { |candidate| domain_match?(candidate, domain) } }
      unexpected = actual.reject { |candidate| expected.any? { |domain| domain_match?(candidate, domain) } }
      result("required_domains", expected, actual, missing.empty? && unexpected.empty?,
             "missing" => missing, "unexpected" => unexpected)
    end

    def evaluate_forbidden_domains(expected)
      expected = Array(expected).map { |domain| normalize_domain(domain) }
      actual = actual_domains
      found = actual.select { |candidate| expected.any? { |domain| domain_match?(candidate, domain) } }
      result("forbidden_domains", expected, actual, found.empty?, "found" => found)
    end

    def evaluate_title_contains(expected)
      evaluate_text_contains("title_contains", expected, "title")
    end

    def evaluate_snippet_contains(expected)
      evaluate_text_contains("snippet_contains", expected, "snippet")
    end

    def evaluate_maximum_response_time_ms(expected)
      actual = @response_time_ms.to_i
      result("maximum_response_time_ms", expected.to_i, actual, actual <= expected.to_i)
    end

    def evaluate_required_fields(expected)
      fields = Array(expected).map(&:to_s)
      missing = fields.reject { |path| path_present?(@data, path.split(".")) }
      result("required_fields", fields, fields - missing, missing.empty?, "missing" => missing)
    end

    def evaluate_text_contains(name, expected, field)
      expected = Array(expected).map { |value| value.to_s.downcase }
      corpus = @results.map { |item| item.to_h[field].to_s.downcase }
      missing = expected.reject { |term| corpus.any? { |text| text.include?(term) } }
      result(name, expected, corpus, missing.empty?, "missing" => missing)
    end

    def path_present?(value, segments)
      return !value.nil? if segments.empty?

      segment = segments.first
      if segment.end_with?("[]")
        key = segment.delete_suffix("[]")
        array = value.is_a?(Hash) ? value[key] : nil
        return Array(array).any? { |item| path_present?(item, segments.drop(1)) }
      end
      value.is_a?(Hash) && value.key?(segment) && path_present?(value[segment], segments.drop(1))
    end

    def actual_domains
      @results.filter_map { |item| normalize_domain(item.to_h["domain"]).presence }.uniq
    end

    def normalize_domain(value)
      value.to_s.downcase.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").split("/").first
    end

    def domain_match?(actual, expected)
      actual == expected || actual.end_with?(".#{expected}")
    end

    def result(assertion, expected, actual, passed, details = {})
      {
        "assertion" => assertion,
        "expected" => expected,
        "actual" => actual,
        "passed" => passed,
        "details" => details
      }
    end
  end
end
