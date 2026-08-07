# frozen_string_literal: true

module Ironclad
  module Cache
    # No-op cache for platforms without a supported OS keystore. Every lookup
    # misses, so the key is fetched from the source each call.
    class Null
      def read(_name) = nil

      def write(_name, _key) = true
    end
  end
end
