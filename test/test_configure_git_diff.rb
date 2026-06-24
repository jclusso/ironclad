# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class TestConfigureGitDiff < Minitest::Test
  def test_noop_when_not_enrolled
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        assert_nil Ironclad.configure_git_diff!
      end
    end
  end

  def test_configures_driver_when_enrolled
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system('git', 'init', '-q', out: File::NULL)
        File.write('.gitattributes',
                   "config/credentials.yml.enc diff=rails_credentials\n")

        assert Ironclad.configure_git_diff!('bin/ironclad diff')
        configured = `git config --get diff.rails_credentials.textconv`.chomp
        assert_equal 'bin/ironclad diff', configured
      end
    end
  end
end
