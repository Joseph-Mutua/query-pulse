module Comparison
  class SnapshotBuilder
    def self.call(monitor:, search_run:, normalized_data:)
      schema = SchemaExtractor.call(normalized_data)
      Snapshot.create!(
        monitor: monitor,
        search_run: search_run,
        normalized_data: normalized_data,
        schema: schema,
        schema_hash: CanonicalJson.hash(schema),
        content_hash: CanonicalJson.hash(normalized_data),
        captured_at: search_run.completed_at || Time.current
      )
    end
  end
end
