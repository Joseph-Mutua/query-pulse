require "digest"

module Comparison
  module CanonicalJson
    module_function

    def dump(value)
      JSON.generate(sort(value))
    end

    def hash(value)
      Digest::SHA256.hexdigest(dump(value))
    end

    def sort(value)
      case value
      when Hash
        value.stringify_keys.keys.sort.to_h { |key| [key, sort(value.stringify_keys[key])] }
      when Array
        value.map { |item| sort(item) }
      else
        value
      end
    end
  end
end
