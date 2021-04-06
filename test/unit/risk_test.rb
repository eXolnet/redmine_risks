require File.expand_path('../../test_helper', __FILE__)

class RiskTest < ActiveSupport::TestCase

  def test_extreme_impact_and_probability
    risk = Risk.new(:probability => 99, :impact => 99)

    assert_nothing_raised do
      assert_equal I18n.t("label_risk_level_#{Risk::RISK_MAGNITUDE.last}".to_sym), risk.magnitude
    end
  end

end
