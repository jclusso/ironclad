# frozen_string_literal: true

require 'yaml'

module Ironclad
  # Project configuration, read from config/ironclad.yml so both the CLI (no
  # Rails boot) and the Railtie can load it. Any environment names work — they
  # only have to match the keys you define here.
  #
  #   account: my_app   # optional
  #   keys:
  #     default:    op://VAULT/my_app/master.key
  #     production: op://VAULT/my_app/production.key
  #
  # `app` (the OS-keystore cache namespace) is optional; it defaults to the
  # Rails app name read from config/application.rb.
  class Config
    attr_reader :app, :account, :keys

    def self.load(path)
      unless File.exist?(path)
        raise Error, "Ironclad config not found at #{path}. " \
                     'Run `rails generate ironclad:install` to create it.'
      end

      root = File.dirname(path, 2)
      data = YAML.safe_load_file(path)
      unless data.is_a?(Hash)
        raise Error, "#{path} is empty or not a YAML mapping"
      end

      new(data, root: root)
    end

    # Cache namespace, derived from the app's module name in
    # config/application.rb (falling back to the directory name) so the railtie
    # and the no-Rails CLI agree on one OS-keystore entry per app.
    def self.app_namespace(root)
      return 'ironclad' unless root

      app_rb = File.join(root, 'config', 'application.rb')
      name = File.file?(app_rb) ? File.read(app_rb)[/^\s*module\s+([A-Za-z]\w*)/, 1] : nil
      name ||= File.basename(root)
      name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
    end

    def initialize(data, root: nil)
      @app = data['app'] || self.class.app_namespace(root)
      @account = data['account']
      @keys = data.fetch('keys') { raise Error, 'ironclad.yml is missing `keys`' }
      unless @keys.is_a?(Hash)
        raise Error, 'ironclad.yml `keys` must be a mapping of environment => secret reference'
      end
    end

    def reference(environment)
      keys.fetch(environment) do
        raise Error, "No secret reference for `#{environment}`. " \
                     "Known environments: #{keys.keys.join(', ')}."
      end
    end

    def environments
      keys.keys
    end

    def key?(environment)
      keys.key?(environment)
    end

    # The config key to use for a Rails environment: its own if defined,
    # otherwise `default` (the master key). Nil if neither exists.
    def key_for(environment)
      return environment if key?(environment)

      'default' if key?('default')
    end

    # OS keystore service name for an environment's cached key.
    def cache_key(environment)
      "#{app}-credentials-#{environment}"
    end
  end
end
