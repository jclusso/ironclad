# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'ironclad'

require 'minitest/autorun'
require 'minitest/mock'
require 'minitest/reporters'

Minitest::Reporters.use! [
  Minitest::Reporters::ProgressReporter.new(color: true)
]
