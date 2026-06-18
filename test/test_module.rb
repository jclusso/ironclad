# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class TestModule < Minitest::Test
  def teardown
    Ironclad.config_path = nil
    Ironclad.reset!
  end

  def test_config_path_defaults_under_cwd
    Ironclad.config_path = nil
    assert_equal File.join(Dir.pwd, 'config', 'ironclad.yml'),
                 Ironclad.config_path
  end

  def test_config_path_is_overridable
    Ironclad.config_path = '/somewhere/ironclad.yml'
    assert_equal '/somewhere/ironclad.yml', Ironclad.config_path
  end

  def test_configured_reflects_file_presence
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'ironclad.yml')
      Ironclad.config_path = path
      refute_predicate Ironclad, :configured?

      File.write(path, "keys:\n  default: op://Vault/acme/master.key\n")
      assert_predicate Ironclad, :configured?
    end
  end

  def test_config_is_loaded_and_memoized
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'ironclad.yml')
      File.write(path, "keys:\n  default: op://Vault/acme/master.key\n")
      Ironclad.config_path = path
      Ironclad.reset!

      config = Ironclad.config
      assert_instance_of Ironclad::Config, config
      assert_same config, Ironclad.config
    end
  end

  def test_key_delegates_to_store_with_stringified_env
    store = Minitest::Mock.new
    store.expect(:key, 'secret', ['production'], refresh: true)

    Ironclad.stub(:store, store) do
      assert_equal 'secret', Ironclad.key(:production, refresh: true)
    end
    store.verify
  end
end
