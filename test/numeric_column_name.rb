require 'test_helper'

class NumericColumnNameTest < ActiveSupport::TestCase
  def teardown
    NumericColumnName.destroy_all
  end

  def test_create
    NumericColumnName.create! :"2x" => :x
  end

end
