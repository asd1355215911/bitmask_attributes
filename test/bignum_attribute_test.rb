require 'test_helper'

class BignumAttributeTest < ActiveSupport::TestCase
  def setup
    @last = BignumAttribute.values_for_values.last
  end

  def teardown
    BignumAttribute.destroy_all
  end

  def test_creation
    model = BignumAttribute.create! values: @last
    assert_equal model.values, [@last]
    assert_equal model[:values].class, Bignum
  end

  def test_assignment
    model = BignumAttribute.new
    model.values = BignumAttribute.bitmask_for_values(@last)
    assert_equal model.values, [@last]
  end
end

