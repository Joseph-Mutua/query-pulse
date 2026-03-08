module Comparison
  class SchemaExtractor
    def self.call(value)
      new.extract(value)
    end

    def extract(value)
      case value
      when Hash
        value.stringify_keys.keys.sort.to_h { |key| [key, extract(value.stringify_keys.fetch(key))] }
      when Array
        { "type" => "array", "items" => merge_schemas(value.map { |item| extract(item) }) }
      when Integer then "integer"
      when Float then "float"
      when Numeric then "number"
      when String then "string"
      when TrueClass, FalseClass then "boolean"
      when NilClass then "null"
      else value.class.name.underscore
      end
    end

    private

    def merge_schemas(schemas)
      return "unknown" if schemas.empty?
      return schemas.first if schemas.uniq.one?

      if schemas.all? { |schema| schema.is_a?(Hash) && schema["type"] != "array" }
        keys = schemas.flat_map(&:keys).uniq.sort
        return keys.to_h do |key|
          present = schemas.filter_map { |schema| schema[key] }
          [key, merge_schemas(present)]
        end
      end

      { "anyOf" => schemas.uniq.sort_by { |schema| Comparison::CanonicalJson.dump(schema) } }
    end
  end
end
