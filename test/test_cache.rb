# frozen_string_literal: true

require 'test_helper'

class TestCache < Minitest::Test
  def test_darwin_uses_keychain
    cache = Ironclad::Cache.for_platform('app', 'darwin23')
    assert_instance_of Ironclad::Cache::Keychain, cache
  end

  def test_linux_with_keyctl_uses_keyctl
    Ironclad::Cache.stub(:keyctl_available?, true) do
      cache = Ironclad::Cache.for_platform('app', 'linux-gnu')
      assert_instance_of Ironclad::Cache::Keyctl, cache
    end
  end

  def test_linux_without_keyctl_uses_null
    Ironclad::Cache.stub(:keyctl_available?, false) do
      cache = Ironclad::Cache.for_platform('app', 'linux-gnu')
      assert_instance_of Ironclad::Cache::Null, cache
    end
  end

  def test_unknown_platform_uses_null
    cache = Ironclad::Cache.for_platform('app', 'solaris')
    assert_instance_of Ironclad::Cache::Null, cache
  end

  def test_null_cache_reads_and_writes_nil
    cache = Ironclad::Cache::Null.new
    assert_nil cache.read('anything')
    assert_nil cache.write('anything', 'value')
  end

  def test_keychain_read_returns_value_on_hit
    cache = Ironclad::Cache::Keychain.new('app')
    status = Minitest::Mock.new
    status.expect(:success?, true)

    Open3.stub(:capture3, ["the-key\n", '', status]) do
      assert_equal 'the-key', cache.read('default')
    end
    status.verify
  end

  def test_keychain_read_returns_nil_on_miss
    cache = Ironclad::Cache::Keychain.new('app')
    status = Minitest::Mock.new
    status.expect(:success?, false)

    # On a cache miss the security tool writes to stderr; capture3 swallows it
    # so it never leaks to the terminal.
    err = 'security: SecKeychainSearchCopyNext: ' \
          'The specified item could not be found in the keychain.'
    Open3.stub(:capture3, ['', err, status]) do
      assert_nil cache.read('default')
    end
    status.verify
  end
end
