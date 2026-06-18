# frozen_string_literal: true

require 'rbconfig'
require_relative 'cache/keychain'
require_relative 'cache/keyctl'
require_relative 'cache/null'

module Ironclad
  # Selects the OS keystore backend for the current platform.
  module Cache
    module_function

    def for_platform(account, host_os = RbConfig::CONFIG['host_os'])
      case host_os
      when /darwin/
        Keychain.new(account)
      when /linux/
        keyctl_available? ? Keyctl.new : Null.new
      else
        Null.new
      end
    end

    def keyctl_available?
      system('command -v keyctl', out: File::NULL, err: File::NULL)
    end
  end
end
