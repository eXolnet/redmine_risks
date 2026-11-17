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

  def test_assigning_closed_status_should_set_closed_on
    risk = Risk.find(1)
    risk.status = 'closed'
    risk.save!

    assert_not_nil risk.reload.closed_on
    assert risk.closed?
  end

  def test_assigning_open_status_should_clear_closed_on
    risk = Risk.find(2)
    risk.status = 'open'
    risk.save!

    assert_nil risk.reload.closed_on
    assert_not risk.closed?
  end

  def test_switching_between_closed_statuses_should_keep_closed_on
    risk = Risk.find(2)
    closed_on = risk.closed_on
    risk.status = 'rejected'
    risk.save!

    assert_equal closed_on, risk.reload.closed_on
  end
end
