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
end
