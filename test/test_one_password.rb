# frozen_string_literal: true

require 'test_helper'

class TestOnePassword < Minitest::Test
  def test_read_raises_ironclad_error_when_op_is_missing
    source = Ironclad::Source::OnePassword.new
    missing = ->(*) { raise Errno::ENOENT, 'op' }

    error = Open3.stub(:capture3, missing) do
      assert_raises(Ironclad::Error) { source.read('op://vault/item/field') }
    end

    assert_match(/1Password CLI \(op\) not found/, error.message)
  end
end
