# frozen_string_literal: true

require 'open3'

module Ironclad
  module Source
    # Reads a secret from 1Password via the `op` CLI.
    class OnePassword
      def initialize(account = nil)
        @account = account
      end

      def read(reference)
        cmd = ['op', 'read', reference]
        cmd.push('--account', @account) if @account

        out, err, status = Open3.capture3(*cmd)
        unless status.success?
          message = 'Could not read the credentials key from 1Password. ' \
                    'Authorize the prompt and retry, or run: op signin'
          detail = err.strip
          message += " (#{detail})" unless detail.empty?
          raise Error, message
        end

        out.chomp
      end
    end
  end
end
