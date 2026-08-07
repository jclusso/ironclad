# frozen_string_literal: true

require 'open3'

module Ironclad
  module Cache
    # macOS Keychain via the `security` tool. The cache never expires; a key
    # rotation is handled by writing (-U updates) the new value.
    class Keychain
      def initialize(account)
        @account = account
      end

      def read(name)
        out, _err, status = Open3.capture3(
          'security', 'find-generic-password',
          '-a', @account, '-s', name, '-w'
        )
        status.success? ? out.chomp : nil
      end

      def write(name, key)
        # The key passes via argv (briefly visible to the same user's `ps`); the
        # security tool has no stdin input mode. Acceptable for a local cache.
        # system returns nil when `security` cannot be executed at all, which is
        # a failure to cache just as much as a non-zero exit is.
        system(
          'security', 'add-generic-password', '-U',
          '-a', @account, '-s', name, '-w', key,
          out: File::NULL, err: File::NULL
        ) || false
      end
    end
  end
end
