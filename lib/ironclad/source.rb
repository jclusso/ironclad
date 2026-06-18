# frozen_string_literal: true

module Ironclad
  # Namespace for secret sources. A source responds to #read(reference) and
  # returns the secret as a string, raising Ironclad::Error on failure.
  # OnePassword is the only source today; add another manager as a sibling
  # class here and have KeyStore select it.
  module Source
  end
end
