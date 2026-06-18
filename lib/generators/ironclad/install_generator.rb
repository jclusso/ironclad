# frozen_string_literal: true

require 'rails/generators/base'

module Ironclad
  module Generators
    # Installs Ironclad: asks which environments you manage, writes a
    # config/ironclad.yml to fill in and a bin/ironclad binstub, then asks about
    # optional integrations.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_config
        create_file 'config/ironclad.yml', config_contents
      end

      def create_binstub
        copy_file 'binstub', 'bin/ironclad'
        chmod 'bin/ironclad', 0o755
      end

      def create_vscode_task
        return unless yes?("Add a VS Code 'Edit Credentials' task? (y/N)")

        template 'tasks.json', '.vscode/tasks.json'
      end

      def setup_capistrano
        return unless File.exist?(File.join(destination_root, 'Capfile'))
        return unless yes?('Wire Ironclad into your Capfile for deploys? (y/N)')

        inject_into_file 'Capfile', "require 'ironclad/capistrano'\n",
                         after: %r{^require ['"]capistrano/setup['"].*\n}
      end

      def show_post_install
        say <<~MESSAGE

          Ironclad installed. Edit config/ironclad.yml and fill in your
          1Password references. In CI / on servers, set RAILS_MASTER_KEY from a
          secret instead.

          Print a key:      bin/ironclad [env]
          Edit credentials: bin/ironclad edit [env]
        MESSAGE
      end

      private

      def environments
        @environments ||= ask(
          'Environments to manage? (comma-separated)',
          default: 'default'
        ).split(',').map(&:strip).reject(&:empty?)
      end

      def config_contents
        keys = environments.map do |env|
          field = env == 'default' ? 'master' : env
          "  #{env}: op://VAULT/#{app_name}/#{field}.key"
        end.join("\n")

        <<~YAML
          # Maps each environment to a 1Password secret reference. Replace VAULT
          # (and the item/field if needed) to match your vault. `default` is the
          # development/master key.
          account:
          keys:
          #{keys}
        YAML
      end

      def app_name
        Rails.application.class.module_parent_name.underscore
      rescue StandardError
        File.basename(destination_root)
      end
    end
  end
end
