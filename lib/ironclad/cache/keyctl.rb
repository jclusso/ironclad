# frozen_string_literal: true

require 'open3'

module Ironclad
  module Cache
    # Linux kernel keyring via `keyctl`, stored in the user keyring (@u): it
    # persists across this user's sessions and clears on reboot, at which point
    # a miss simply re-seeds from the source.
    class Keyctl
      def read(name)
        id, status = Open3.capture2('keyctl', 'search', '@u', 'user', name)
        return unless status.success?

        out, status = Open3.capture2('keyctl', 'pipe', id.chomp)
        status.success? ? out : nil
      end

      def write(name, key)
        Open3.capture2('keyctl', 'padd', 'user', name, '@u', stdin_data: key)
      end
    end
  end
end
