# frozen_string_literal: true

require 'open3'

module Ironclad
  module Cache
    # Linux kernel keyring via `keyctl`, stored in the user keyring (@u): it
    # persists across this user's sessions and clears on reboot, at which point
    # a miss simply re-seeds from the source.
    class Keyctl
      def self.available?
        ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? do |dir|
          File.executable?(File.join(dir, 'keyctl'))
        end
      end

      def read(name)
        id, _error, status = Open3.capture3(
          'keyctl', 'search', '@u', 'user', name
        )
        return unless status.success?

        out, _error, status = Open3.capture3('keyctl', 'pipe', id.chomp)
        status.success? ? out : nil
      end

      def write(name, key)
        # `keyctl padd` creates the key with the kernel's default permissions
        # and offers no way to set them at creation, so changing them afterwards
        # needs setattr, which only a possessor has. @u grants the owning user
        # link permission, so linking it into @s first guarantees possession.
        Open3.capture3('keyctl', 'link', '@u', '@s')

        id, error, status = Open3.capture3(
          'keyctl', 'padd', 'user', name, '@u', stdin_data: key
        )
        return warn_failure(error, "cache #{name}") unless status.success?

        # possessor 0x3f (all), user 0x2f (view, read, write, search, setattr),
        # group and other none. A caller that does not possess the key gets only
        # the user byte, which has to cover every operation performed here.
        _out, error, status = Open3.capture3(
          'keyctl', 'setperm', id.chomp, '0x3f2f0000'
        )
        return warn_failure(error, "set permissions on #{name}") unless status.success?

        true
      end

      private

      def warn_failure(error, action)
        detail = error.strip
        message = "ironclad: could not #{action} in the Linux keyring"
        message += ": #{detail}" unless detail.empty?
        warn message
        false
      end
    end
  end
end
