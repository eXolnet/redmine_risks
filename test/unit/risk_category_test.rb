require File.expand_path('../../test_helper', __FILE__)

class RiskCategoryTest < ActiveSupport::TestCase
  fixtures :projects, :users, :enumerations, :risks

  def setup
    @technical = RiskCategory.create!(:name => 'Technical')
    @financial = RiskCategory.create!(:name => 'Financial')
    Risk.where(:id => [1, 2]).update_all(:category_id => @technical.id)
  end

  def test_option_name
    assert_equal :enumeration_risk_categories, @technical.option_name
  end

  def test_objects_count
    assert_equal 2, @technical.objects_count
    assert_equal 0, @financial.objects_count
    assert @technical.in_use?
    assert_not @financial.in_use?
  end

  def test_destroy_with_reassign_should_transfer_risks
    @technical.destroy(@financial)

    assert_nil RiskCategory.find_by_id(@technical.id)
    assert_equal [@financial.id], Risk.where(:id => [1, 2]).distinct.pluck(:category_id)
    assert_equal 2, @financial.objects_count
  end

  def test_default_should_return_default_category
    @financial.update!(:is_default => true)

    assert_equal @financial, RiskCategory.default
  end

  def test_default_without_default_category_should_return_first_category
    assert_equal RiskCategory.first, RiskCategory.default
    assert_not_nil RiskCategory.default
  end

  def test_default_without_categories_should_be_nil
    RiskCategory.delete_all

    assert_nil RiskCategory.default
  end
end
