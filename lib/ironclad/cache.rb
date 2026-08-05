# frozen_string_literal: true

require 'rbconfig'
require_relative 'cache/keychain'
require_relative 'cache/keyctl'
require_relative 'cache/null'

module Ironclad
  # Selects the OS keystore backend for the current platform. A backend responds
  # to #read(name), returning the cached string or nil, and #write(name, key),
  # returning true when the key is cached and false when it is not. A backend
  # with nowhere to store keys reports true: nothing to do is not a failure.
  module Cache
    module_function

    def for_platform(account, host_os = RbConfig::CONFIG['host_os'])
      case host_os
      when /darwin/
        Keychain.new(account)
      when /linux/
        return Keyctl.new if Keyctl.available?

        warn 'ironclad: keyctl not found, so key caching is disabled and keys ' \
             'are fetched from the source every time. Install keyutils to ' \
             'enable the kernel keyring cache.'
        Null.new
      else
        Null.new
      end
    end
  end
end
