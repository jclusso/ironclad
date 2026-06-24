# frozen_string_literal: true

require 'active_support'
require 'active_support/encrypted_file'

module Ironclad
  module Diff
    ENV_KEY = 'IRONCLAD_DIFF_KEY'

    module_function

    def call(path, out = $stdout)
      out.write(decrypt(path) || File.read(path))
    end

    def decrypt(path)
      key = Ironclad.key(environment_for(path))
      return unless key

      ENV[ENV_KEY] = key
      ActiveSupport::EncryptedFile.new(
        content_path: path, key_path: File::NULL,
        env_key: ENV_KEY, raise_if_missing_key: true
      ).read
    rescue Ironclad::Error, ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    def environment_for(path)
      env = File.basename(path).delete_suffix('.yml.enc')
      Ironclad.config.key?(env) ? env : 'default'
    end
  end
end
