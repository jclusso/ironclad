# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'securerandom'

class TestKeyctl < Minitest::Test
  def setup
    skip 'Linux only' unless RbConfig::CONFIG['host_os'].match?(/linux/)

    @name = "ironclad-test-#{Process.pid}-#{SecureRandom.hex(8)}"
    @cache = Ironclad::Cache::Keyctl.new
  end

  def teardown
    return unless @cache

    id, status = Open3.capture2('keyctl', 'search', '@u', 'user', @name)
    return unless status.success?

    system('keyctl', 'unlink', id.chomp, '@u', out: File::NULL, err: File::NULL)
  end

  def test_write_then_read_round_trips
    @cache.write(@name, 'the-secret-key')
    assert_equal 'the-secret-key', @cache.read(@name)
  end

  def test_read_miss_returns_nil
    assert_nil @cache.read("missing-#{SecureRandom.hex(8)}")
  end

  def test_write_updates_existing_value
    @cache.write(@name, 'first')
    @cache.write(@name, 'second')
    assert_equal 'second', @cache.read(@name)
  end
end
