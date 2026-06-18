# frozen_string_literal: true

module Ironclad
  # Read-through cache: keys are read from the local OS keystore and pulled from
  # the source only on a miss, so repeated calls don't round-trip to it.
  class KeyStore
    def initialize(config, cache: nil, source: nil)
      @config = config
      @cache = cache || Cache.for_platform(config.app)
      # Defaults to 1Password; inject another source to use a different manager.
      @source = source || Source::OnePassword.new(config.account)
    end

    # Return the key for an environment. With refresh: true, skip the cache and
    # re-seed it from the source (use after a key rotation).
    def key(environment, refresh: false)
      name = @config.cache_key(environment)

      unless refresh
        cached = @cache.read(name)
        return cached if cached && !cached.empty?
      end

      fetched = @source.read(@config.reference(environment))
      @cache.write(name, fetched)
      fetched
    end
  end
end
