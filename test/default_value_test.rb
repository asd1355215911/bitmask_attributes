require 'test_helper'

class DefaultValueTest < ActiveSupport::TestCase
  def teardown
    DefaultValue.destroy_all
  end

  def test_initialization
    assert_equal DefaultValue.new.default_sym, [:y]
    assert_equal DefaultValue.new.default_array, [:y, :z]
    assert_equal DefaultValue.new(:default_sym => :x).default_sym, [:x]
    assert_equal DefaultValue.new(:default_array => [:x]).default_array, [:x]
    assert_equal DefaultValue.new(:default_sym => []).default_sym, []
  end

  def test_assignment
    model = DefaultValue.new(:default_sym => :x)
    model.default_sym = nil
    assert_equal model.default_sym, [:y]
  end
end

