# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'securerandom'

class TestKeyctl < Minitest::Test
  Status = Struct.new(:success) do
    def success? = success
  end

  def setup
    skip 'Linux only' unless RbConfig::CONFIG['host_os'].match?(/linux/)

    @name = "ironclad-test-#{Process.pid}-#{SecureRandom.hex(8)}"
    @cache = Ironclad::Cache::Keyctl.new
  end

  def teardown
    return unless @cache

    id, _error, status = Open3.capture3('keyctl', 'search', '@u', 'user', @name)
    return unless status.success?

    system('keyctl', 'unlink', id.chomp, '@u', out: File::NULL, err: File::NULL)
  end

  def test_write_then_read_round_trips
    assert @cache.write(@name, 'the-secret-key')
    assert_equal 'the-secret-key', @cache.read(@name)
  end

  def test_write_grants_the_owning_user_access_across_sessions
    @cache.write(@name, 'the-secret-key')
    id, status = Open3.capture2('keyctl', 'search', '@u', 'user', @name)
    assert status.success?

    description, status = Open3.capture2('keyctl', 'rdescribe', id.chomp)
    assert status.success?
    assert_equal '3f2f0000', description.split(';')[3]

    cached, _, status = Open3.capture3(
      'keyctl', 'session', '-', 'keyctl', 'pipe', id.chomp
    )
    assert status.success?
    assert_equal 'the-secret-key', cached
  end

  def test_write_creates_a_usable_key_from_a_non_possessing_session
    _out, error, status = write_in_new_session(@name, 'the-secret-key')
    assert_predicate status, :success?, error
    refute_match(/could not/i, error)

    id, _error, status = Open3.capture3('keyctl', 'search', '@u', 'user', @name)
    assert_predicate status, :success?

    description, = Open3.capture2('keyctl', 'rdescribe', id.chomp)
    assert_equal '3f2f0000', description.split(';')[3]
    assert_equal 'the-secret-key', @cache.read(@name)
  end

  def test_write_updates_existing_value_from_a_non_possessing_session
    @cache.write(@name, 'first')

    _out, error, status = write_in_new_session(@name, 'second')
    assert_predicate status, :success?, error
    refute_match(/could not/i, error)

    assert_equal 'second', @cache.read(@name)
  end

  def test_read_miss_returns_nil
    assert_nil @cache.read("missing-#{SecureRandom.hex(8)}")
  end

  def test_write_updates_existing_value
    @cache.write(@name, 'first')
    @cache.write(@name, 'second')
    assert_equal 'second', @cache.read(@name)
  end

  def test_write_warns_and_returns_false_when_keyctl_fails
    stub = lambda do |*args, **|
      next ['', 'permission denied', Status.new(false)] if args.include?('padd')

      ['', '', Status.new(true)]
    end

    result = nil
    _out, error = capture_io do
      Open3.stub(:capture3, stub) do
        result = @cache.write(@name, 'the-secret-key')
      end
    end

    refute result
    assert_match(/could not cache/, error)
    assert_match(/permission denied/, error)
  end

  def test_write_warns_and_returns_false_when_setting_permissions_fails
    stub = lambda do |*args, **|
      next ['', 'permission denied', Status.new(false)] if args.include?('setperm')

      ['12345', '', Status.new(true)]
    end

    result = nil
    _out, error = capture_io do
      Open3.stub(:capture3, stub) do
        result = @cache.write(@name, 'the-secret-key')
      end
    end

    refute result
    assert_match(/could not set permissions/, error)
    assert_match(/permission denied/, error)
  end

  private

  def write_in_new_session(name, value)
    script = <<~RUBY
      $LOAD_PATH.unshift(#{File.expand_path('../lib', __dir__).inspect})
      require 'ironclad'
      Ironclad::Cache::Keyctl.new.write(#{name.inspect}, #{value.inspect})
    RUBY

    Open3.capture3(
      'keyctl', 'session', '-', RbConfig.ruby, '-e', script
    )
  end
end
