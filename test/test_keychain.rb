# frozen_string_literal: true

require 'test_helper'
require 'securerandom'
class TestKeychain < Minitest::Test
  def setup
    skip 'macOS only' unless RbConfig::CONFIG['host_os'].match?(/darwin/)

    @account = "ironclad-test-#{Process.pid}"
    @name = "key-#{SecureRandom.hex(8)}"
    @cache = Ironclad::Cache::Keychain.new(@account)
  end

  def teardown
    return unless @cache

    system('security', 'delete-generic-password', '-a', @account, '-s', @name,
           out: File::NULL, err: File::NULL)
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
