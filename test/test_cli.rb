# frozen_string_literal: true

require 'test_helper'
require 'ironclad/cli'

class TestCLI < Minitest::Test
  def test_help_returns_zero_and_prints_usage
    code = nil
    out, = capture_io { code = Ironclad::CLI.start(['--help']) }
    assert_equal 0, code
    assert_match(/Usage:/, out)
  end

  def test_prints_key_for_given_env
    with_config(%w[default production]) do
      Ironclad.stub(:key, ->(env) { "K:#{env}" }) do
        out, = capture_io { Ironclad::CLI.start(['production']) }
        assert_equal "K:production\n", out
      end
    end
  end

  def test_refresh_without_an_env_refreshes_the_default_key
    seen = []
    recorder = lambda do |env, refresh: false|
      seen << [env, refresh]
      'k'
    end

    code = nil
    with_config(%w[default staging production]) do
      Ironclad.stub(:key, recorder) do
        out, = capture_io { code = Ironclad::CLI.start(['refresh']) }
        assert_equal "default: refreshed\n", out
      end
    end
    assert_equal 0, code
    assert_equal [['default', true]], seen
  end

  def test_refresh_with_env_refreshes_only_that_environment
    seen = []
    recorder = lambda do |env, refresh: false|
      seen << [env, refresh]
      'k'
    end

    code = nil
    with_config(%w[default staging production]) do
      Ironclad.stub(:key, recorder) do
        out, = capture_io { code = Ironclad::CLI.start(%w[refresh staging]) }
        assert_equal "staging: refreshed\n", out
      end
    end
    assert_equal 0, code
    assert_equal [['staging', true]], seen
  end

  def test_refresh_with_unknown_env_warns_and_returns_one
    code = nil
    with_config(%w[default]) do
      out, err = capture_io { code = Ironclad::CLI.start(%w[refresh staging]) }
      assert_equal 1, code
      assert_empty out
      assert_match(/Unknown environment/, err)
    end
  end

  def test_refresh_all_refreshes_every_configured_environment
    seen = []
    recorder = lambda do |env, refresh: false|
      seen << [env, refresh]
      'k'
    end

    code = nil
    with_config(%w[default staging production]) do
      Ironclad.stub(:key, recorder) do
        out, = capture_io { code = Ironclad::CLI.start(%w[refresh --all]) }
        assert_equal <<~OUT, out
          default: refreshed
          staging: refreshed
          production: refreshed
        OUT
      end
    end
    assert_equal 0, code
    expected = [['default', true], ['staging', true], ['production', true]]
    assert_equal expected, seen
  end

  def test_refresh_all_continues_past_a_failure_and_returns_one
    failing = lambda do |env, refresh: false|
      raise Ironclad::Error, 'op is not signed in' if env == 'staging'

      'k'
    end

    code = nil
    with_config(%w[default staging production]) do
      Ironclad.stub(:key, failing) do
        out, err = capture_io { code = Ironclad::CLI.start(%w[refresh --all]) }
        assert_equal <<~OUT, out
          default: refreshed
          production: refreshed
        OUT
        assert_match(/staging: op is not signed in/, err)
        assert_match(/Failed to refresh: staging\./, err)
      end
    end
    assert_equal 1, code
  end

  def test_refresh_reports_a_cache_failure_and_returns_one
    failing = lambda do |_env, refresh: false|
      assert refresh
      raise Ironclad::Error, 'Could not cache refreshed credentials key'
    end

    code = nil
    with_config(%w[default]) do
      Ironclad.stub(:key, failing) do
        out, err = capture_io do
          code = Ironclad::CLI.start(%w[refresh default])
        end
        assert_empty out
        assert_match(/Could not cache refreshed credentials key/, err)
      end
    end
    assert_equal 1, code
  end

  def test_refresh_all_with_no_environments_warns_and_returns_one
    code = nil
    with_config([]) do
      out, err = capture_io { code = Ironclad::CLI.start(%w[refresh --all]) }
      assert_equal 1, code
      assert_empty out
      assert_match(/No environments are configured/, err)
    end
  end

  def test_unknown_env_warns_and_returns_one
    code = nil
    with_config(%w[default]) do
      out, err = capture_io { code = Ironclad::CLI.start(['staging']) }
      assert_equal 1, code
      assert_empty out
      assert_match(/Unknown environment/, err)
    end
  end

  private

  def with_config(envs, &)
    keys = envs.to_h { |e| [e, "op://Vault/acme/#{e}.key"] }
    Ironclad.stub(:config, Ironclad::Config.new({ 'keys' => keys }), &)
  end
end
