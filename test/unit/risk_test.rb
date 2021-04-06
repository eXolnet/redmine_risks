require File.expand_path('../../test_helper', __FILE__)

class RiskTest < ActiveSupport::TestCase

  def test_magnitude_calculation
    assert_equal "Low", Risk.new(:probability => 100, :impact => 0).magnitude
    assert_equal "Low", Risk.new(:probability => 100, :impact => 24).magnitude
    assert_equal "Medium", Risk.new(:probability => 100, :impact => 25).magnitude
    assert_equal "Medium", Risk.new(:probability => 100, :impact => 49).magnitude
    assert_equal "High", Risk.new(:probability => 100, :impact => 50).magnitude
    assert_equal "High", Risk.new(:probability => 100, :impact => 74).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 75).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 100).magnitude

    assert_equal "Low", Risk.new(:probability => 0, :impact => 100).magnitude
    assert_equal "Low", Risk.new(:probability => 24, :impact => 100).magnitude
    assert_equal "Medium", Risk.new(:probability => 25, :impact => 100).magnitude
    assert_equal "Medium", Risk.new(:probability => 49, :impact => 100).magnitude
    assert_equal "High", Risk.new(:probability => 50, :impact => 100).magnitude
    assert_equal "High", Risk.new(:probability => 74, :impact => 100).magnitude
    assert_equal "Extreme", Risk.new(:probability => 75, :impact => 100).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 100).magnitude

    assert_equal "Low", Risk.new(:probability => 0, :impact => 0).magnitude
    assert_equal "Low", Risk.new(:probability => 25, :impact => 25).magnitude
    assert_equal "Medium", Risk.new(:probability => 50, :impact => 50).magnitude
    assert_equal "High", Risk.new(:probability => 75, :impact => 75).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 100).magnitude
  end

end
