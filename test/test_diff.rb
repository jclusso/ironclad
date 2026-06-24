# frozen_string_literal: true

require 'test_helper'
require 'ironclad/diff'
require 'tmpdir'
require 'securerandom'

class TestDiff < Minitest::Test
  def test_environment_comes_from_the_filename
    with_config(%w[default staging production]) do
      assert_equal 'production',
                   Ironclad::Diff.environment_for('/tmp/git-blob-x/production.yml.enc')
      assert_equal 'staging',
                   Ironclad::Diff.environment_for('config/credentials/staging.yml.enc')
    end
  end

  def test_top_level_and_unrecognized_files_use_the_default_key
    with_config(%w[default production]) do
      assert_equal 'default',
                   Ironclad::Diff.environment_for('config/credentials.yml.enc')
      assert_equal 'default',
                   Ironclad::Diff.environment_for('config/secrets.enc')
    end
  end

  def test_decrypts_with_the_files_environment_key
    key = ActiveSupport::EncryptedFile.generate_key
    with_config(%w[default production]) do
      with_encrypted_file('production.yml.enc', 'secret: 42', key) do |path|
        Ironclad.stub(:key, ->(env, **) { key if env == 'production' }) do
          out, = capture_io { Ironclad::Diff.call(path) }
          assert_equal 'secret: 42', out
        end
      end
    end
  end

  def test_falls_back_to_raw_when_the_key_is_unavailable
    key = ActiveSupport::EncryptedFile.generate_key
    with_config(%w[default production]) do
      with_encrypted_file('production.yml.enc', 'secret: 42', key) do |path|
        Ironclad.stub(:key, ->(*) { raise Ironclad::Error, 'op signed out' }) do
          out, = capture_io { Ironclad::Diff.call(path) }
          assert_equal File.read(path), out
        end
      end
    end
  end

  private

  def with_config(envs, &)
    keys = envs.to_h { |e| [e, "op://Vault/acme/#{e}.key"] }
    Ironclad.stub(:config, Ironclad::Config.new({ 'keys' => keys }), &)
  end

  def with_encrypted_file(name, content, key)
    Dir.mktmpdir do |dir|
      path = File.join(dir, name)
      ENV['SEED_KEY'] = key
      ActiveSupport::EncryptedFile.new(
        content_path: path, key_path: File::NULL,
        env_key: 'SEED_KEY', raise_if_missing_key: true
      ).write(content)
      yield path
    end
  end
end
