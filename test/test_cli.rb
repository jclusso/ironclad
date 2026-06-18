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
      Ironclad.stub(:key, ->(env, refresh: false) { "K:#{env}:#{refresh}" }) do
        out, = capture_io { Ironclad::CLI.start(['production']) }
        assert_equal "K:production:false\n", out
      end
    end
  end

  def test_refresh_flag_is_parsed
    captured = {}
    recorder = lambda do |env, refresh: false|
      captured[:env] = env
      captured[:refresh] = refresh
      'k'
    end
    with_config(%w[default]) do
      Ironclad.stub(:key, recorder) do
        capture_io { Ironclad::CLI.start(['default', '--refresh']) }
      end
    end
    assert_equal 'default', captured[:env]
    assert captured[:refresh]
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
