require "uri"

module Comparison
  class ResultComparator
    DEFAULT_IGNORED_PATHS = %w[
      search_metadata.id search_metadata.created_at search_metadata.processed_at
      search_metadata.response_time_ms provider_data.search_metadata.id
      provider_data.search_metadata.created_at provider_data.search_metadata.processed_at
    ].freeze

    def self.call(previous:, current:, ignored_paths: DEFAULT_IGNORED_PATHS, movement_threshold: 3)
      new(previous:, current:, ignored_paths:, movement_threshold:).call
    end

    def initialize(previous:, current:, ignored_paths:, movement_threshold:)
      @previous = snapshot_data(previous)
      @current = snapshot_data(current)
      @ignored_paths = ignored_paths
      @movement_threshold = movement_threshold.to_i
      @changes = []
    end

    def call
      compare_values(@previous, @current, "")
      { "changes" => @changes, "summary" => @changes.group_by { |change| change["type"] }.transform_values(&:count) }
    end

    private

    def snapshot_data(value)
      value.respond_to?(:normalized_data) ? value.normalized_data : value.to_h.deep_stringify_keys
    end

    def compare_values(previous, current, path)
      return if ignored?(path)
      return add_change(path, "TYPE_CHANGED", previous, current, "critical") if type_of(previous) != type_of(current)

      case previous
      when Hash then compare_hashes(previous.stringify_keys, current.stringify_keys, path)
      when Array then compare_arrays(previous, current, path)
      else
        add_change(path, "VALUE_CHANGED", previous, current, "info") unless previous == current
      end
    end

    def compare_hashes(previous, current, path)
      (previous.keys | current.keys).sort.each do |key|
        child_path = join_path(path, key)
        next if ignored?(child_path)

        if !previous.key?(key)
          add_change(child_path, "FIELD_ADDED", nil, current[key], "info")
        elsif !current.key?(key)
          add_change(child_path, "FIELD_REMOVED", previous[key], nil, "warning")
        else
          compare_values(previous[key], current[key], child_path)
        end
      end
    end

    def compare_arrays(previous, current, path)
      if previous.length != current.length
        add_change(path, "ARRAY_LENGTH_CHANGED", previous.length, current.length,
                   current.empty? ? "critical" : "warning")
      end

      return compare_organic_results(previous, current, path) if path == "organic_results"

      [previous.length, current.length].min.times do |index|
        compare_values(previous[index], current[index], "#{path}[]")
      end
    end

    def compare_organic_results(previous, current, path)
      previous_by_id = index_results(previous)
      current_by_id = index_results(current)
      matched_identities = previous_by_id.keys & current_by_id.keys

      matched_identities.each do |identity|
        before = previous_by_id.fetch(identity)
        after = current_by_id.fetch(identity)
        movement = (after[:position] - before[:position]).abs
        if movement >= @movement_threshold
          add_change(path, "RESULT_ORDER_CHANGED", before[:position], after[:position], "warning",
                     "url" => after[:result]["link"], "previous_position" => before[:position],
                     "current_position" => after[:position], "movement" => movement)
        end
        compare_values(before[:result].except("position"), after[:result].except("position"), "#{path}[]")
      end

      unmatched_previous = previous_by_id.except(*matched_identities).values.sort_by { |item| item[:position] }
      unmatched_current = current_by_id.except(*matched_identities).values.sort_by { |item| item[:position] }
      unmatched_previous.zip(unmatched_current).each do |before, after|
        next unless before && after

        compare_values(before[:result].except("position"), after[:result].except("position"), "#{path}[]")
      end
    end

    def index_results(results)
      results.each_with_index.to_h do |result, index|
        value = result.to_h.deep_stringify_keys
        [result_identity(value), { result: value, position: value["position"].to_i.nonzero? || index + 1 }]
      end
    end

    def result_identity(result)
      canonical_url(result["link"]) || [result["domain"], result["title"].to_s.downcase.squish].join("|")
    end

    def canonical_url(value)
      uri = URI.parse(value.to_s)
      return if uri.host.blank?

      uri.query = nil
      uri.fragment = nil
      uri.host = uri.host.downcase.sub(/\Awww\./, "")
      uri.path = uri.path.sub(%r{/\z}, "")
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    def add_change(path, type, previous, current, severity, metadata = {})
      @changes << {
        "path" => path,
        "type" => type,
        "previous" => previous,
        "current" => current,
        "severity" => severity
      }.merge(metadata)
    end

    def ignored?(path)
      normalized = path.gsub(/\[\d+\]/, "[]")
      @ignored_paths.any? do |ignored|
        normalized == ignored || File.fnmatch?(ignored, normalized, File::FNM_PATHNAME)
      end
    end

    def join_path(parent, key)
      parent.blank? ? key : "#{parent}.#{key}"
    end

    def type_of(value)
      case value
      when Hash then "object"
      when Array then "array"
      when Integer then "integer"
      when Float then "float"
      when Numeric then "number"
      when String then "string"
      when TrueClass, FalseClass then "boolean"
      when NilClass then "null"
      else value.class.name
      end
    end
  end
end
