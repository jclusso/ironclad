# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestIronclad < Minitest::Test
  def setup
    data = {
      'app' => 'acme',
      'account' => 'acme',
      'keys' => {
        'default' => 'op://Vault/acme/master.key',
        'production' => 'op://Vault/acme/production.key'
      }
    }
    @config = Ironclad::Config.new(data)
  end

  def test_app_defaults_to_rails_app_name_from_application_rb
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, 'config'))
      File.write(File.join(root, 'config', 'application.rb'), <<~RUBY)
        module MyCoolApp
          class Application < Rails::Application
          end
        end
      RUBY
      assert_equal 'my_cool_app', Ironclad::Config.app_namespace(root)
    end
  end

  def test_app_namespace_falls_back_to_directory_name
    Dir.mktmpdir do |root|
      app_dir = File.join(root, 'widget_store')
      FileUtils.mkdir_p(app_dir)
      assert_equal 'widget_store', Ironclad::Config.app_namespace(app_dir)
    end
  end

  def test_app_can_be_overridden_in_config
    assert_equal 'acme', @config.app
  end

  def test_that_it_has_a_version_number
    refute_nil ::Ironclad::VERSION
  end

  def test_cache_key_namespaces_by_app_and_env
    assert_equal 'acme-credentials-default', @config.cache_key('default')
  end

  def test_reference_lookup
    assert_equal 'op://Vault/acme/master.key', @config.reference('default')
  end

  def test_reference_raises_for_unknown_env
    error = assert_raises(Ironclad::Error) { @config.reference('staging') }
    assert_match(/No secret reference/, error.message)
  end

  def test_config_load_raises_when_missing
    error = assert_raises(Ironclad::Error) do
      Ironclad::Config.load('/nope/ironclad.yml')
    end
    assert_match(/not found/, error.message)
  end

  def test_key_for_uses_the_environments_own_key_when_defined
    assert_equal 'production', @config.key_for('production')
  end

  def test_key_for_falls_back_to_default_for_unlisted_environments
    assert_equal 'default', @config.key_for('development')
    assert_equal 'default', @config.key_for('test')
    assert_equal 'default', @config.key_for('any_custom_env')
  end

  def test_key_for_is_nil_when_neither_env_nor_default_exist
    data = {
      'app' => 'acme',
      'keys' => { 'production' => 'op://Vault/acme/production.key' }
    }
    assert_nil Ironclad::Config.new(data).key_for('staging')
  end

  def test_key_predicate
    assert @config.key?('production')
    refute @config.key?('staging')
  end

  def test_key_store_returns_cached_value_without_fetching
    cache = FakeCache.new('acme-credentials-default' => 'cached-key')
    source = FakeSource.new
    store = Ironclad::KeyStore.new(@config, cache: cache, source: source)

    assert_equal 'cached-key', store.key('default')
    assert_equal 0, source.reads, 'should not hit 1Password on a cache hit'
  end

  def test_key_store_fetches_and_caches_on_miss
    cache = FakeCache.new
    source = FakeSource.new('op://Vault/acme/master.key' => 'fresh-key')
    store = Ironclad::KeyStore.new(@config, cache: cache, source: source)

    assert_equal 'fresh-key', store.key('default')
    assert_equal 1, source.reads
    assert_equal 'fresh-key', cache.store['acme-credentials-default']
  end

  def test_key_store_refresh_bypasses_cache
    cache = FakeCache.new('acme-credentials-default' => 'stale-key')
    source = FakeSource.new('op://Vault/acme/master.key' => 'rotated-key')
    store = Ironclad::KeyStore.new(@config, cache: cache, source: source)

    assert_equal 'rotated-key', store.key('default', refresh: true)
    assert_equal 'rotated-key', cache.store['acme-credentials-default']
  end

  def test_key_store_returns_fetched_value_when_cache_write_fails
    cache = FailingCache.new
    source = FakeSource.new('op://Vault/acme/master.key' => 'fresh-key')
    store = Ironclad::KeyStore.new(@config, cache: cache, source: source)

    assert_equal 'fresh-key', store.key('default')
  end

  def test_key_store_refresh_raises_when_cache_write_fails
    cache = FailingCache.new
    source = FakeSource.new('op://Vault/acme/master.key' => 'fresh-key')
    store = Ironclad::KeyStore.new(@config, cache: cache, source: source)

    error = assert_raises(Ironclad::CacheWriteError) do
      store.key('default', refresh: true)
    end
    assert_match(/Could not cache refreshed credentials key/, error.message)
    assert_equal 'fresh-key', error.key
  end

  def test_key_store_refresh_accepts_a_cache_with_nowhere_to_store_keys
    cache = Ironclad::Cache::Null.new
    source = FakeSource.new('op://Vault/acme/master.key' => 'fresh-key')
    store = Ironclad::KeyStore.new(@config, cache: cache, source: source)

    assert_equal 'fresh-key', store.key('default', refresh: true)
  end

  def test_key_store_treats_empty_cache_as_miss
    cache = FakeCache.new('acme-credentials-default' => '')
    source = FakeSource.new('op://Vault/acme/master.key' => 'real-key')
    store = Ironclad::KeyStore.new(@config, cache: cache, source: source)

    assert_equal 'real-key', store.key('default')
  end

  class FakeCache
    attr_reader :store

    def initialize(store = {})
      @store = store
    end

    def read(name) = @store[name]

    def write(name, key) = @store[name] = key
  end

  class FakeSource
    attr_reader :reads

    def initialize(refs = {})
      @refs = refs
      @reads = 0
    end

    def read(reference)
      @reads += 1
      @refs.fetch(reference)
    end
  end

  class FailingCache
    def read(_name) = nil

    def write(_name, _key) = false
  end
end
