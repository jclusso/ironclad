# frozen_string_literal: true

require 'test_helper'

class TestCache < Minitest::Test
  def test_darwin_uses_keychain
    cache = Ironclad::Cache.for_platform('app', 'darwin23')
    assert_instance_of Ironclad::Cache::Keychain, cache
  end

  def test_linux_with_keyctl_uses_keyctl
    Ironclad::Cache::Keyctl.stub(:available?, true) do
      cache = Ironclad::Cache.for_platform('app', 'linux-gnu')
      assert_instance_of Ironclad::Cache::Keyctl, cache
    end
  end

  def test_linux_without_keyctl_uses_null_and_warns
    Ironclad::Cache::Keyctl.stub(:available?, false) do
      cache = nil
      _out, err = capture_io do
        cache = Ironclad::Cache.for_platform('app', 'linux-gnu')
      end
      assert_instance_of Ironclad::Cache::Null, cache
      assert_match(/keyctl not found/, err)
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

  def test_keyctl_available_matches_reality
    found = system('command -v keyctl > /dev/null 2>&1')
    assert_equal found, Ironclad::Cache::Keyctl.available?
  end
end
