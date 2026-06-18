# frozen_string_literal: true

module Ironclad
  # Loads the credentials key for the current environment into ENV at boot, so a
  # fresh checkout works with no key file on disk. Each Rails environment uses
  # its own key if one is defined in config/ironclad.yml, otherwise the
  # `default` (master) key.
  #
  # A no-op when RAILS_MASTER_KEY is already set (deployed servers and CI provide
  # the key directly) or when Ironclad isn't configured yet.
  class Railtie < Rails::Railtie
    config.before_configuration do
      Ironclad.config_path = Rails.root.join('config', 'ironclad.yml').to_s
      next if ENV['RAILS_MASTER_KEY'] || !Ironclad.configured?

      name = Ironclad.config.key_for(ENV.fetch('RAILS_ENV', 'development'))
      ENV['RAILS_MASTER_KEY'] = Ironclad.key(name) if name
    rescue Ironclad::Error => e
      # Don't abort boot if the credential source is unavailable (e.g. `op` not
      # signed in or installed). Rails surfaces its own missing-key error later
      # only if credentials are actually accessed.
      warn "Ironclad: could not load credentials key (#{e.message}). " \
           'Try `op signin` or set RAILS_MASTER_KEY.'
    end
  end
end
