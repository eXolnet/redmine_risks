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

  def project_override(category, project = Project.find(1), active = false)
    project.risk_categories.create!(:name => category.name, :parent => category, :active => active)
  end

  def test_objects_count_should_include_project_overrides
    override = project_override(@technical)
    Risk.where(:id => 2).update_all(:category_id => override.id)

    assert_equal 2, @technical.objects_count
    assert_equal 1, override.objects_count
  end

  def test_destroy_system_category_with_reassign_should_transfer_risks_and_delete_overrides
    override = project_override(@technical)
    Risk.where(:id => 2).update_all(:category_id => override.id)

    @technical.destroy(@financial)

    assert_nil RiskCategory.find_by_id(@technical.id)
    assert_nil RiskCategory.find_by_id(override.id)
    assert_equal [@financial.id], Risk.where(:id => [1, 2]).distinct.pluck(:category_id)
  end

  def test_destroy_system_category_in_use_by_override_without_reassign_should_raise
    override = project_override(@financial)
    Risk.where(:id => 2).update_all(:category_id => override.id)

    assert @financial.in_use?
    assert_raise(RuntimeError) { @financial.destroy }
  end

  def test_renaming_system_category_should_rename_overrides
    override = project_override(@technical)
    @technical.update!(:name => 'Technology')

    assert_equal 'Technology', override.reload.name
  end

  def test_default_with_project_should_return_project_override
    @technical.update!(:is_default => true)
    override = project_override(@technical, Project.find(1), true)

    assert_equal override, RiskCategory.default(Project.find(1))
    assert_equal @technical, RiskCategory.default(Project.find(2))
  end

  def test_default_with_project_and_disabled_default_should_be_nil
    @technical.update!(:is_default => true)
    project_override(@technical)

    assert_nil RiskCategory.default(Project.find(1))
  end

  def test_available_categories
    @financial.update!(:active => false)
    project_override(@technical)

    assert_equal [@technical], RiskCategory.available_categories.to_a
    assert_equal [], RiskCategory.available_categories(Project.find(1)).to_a
    assert_equal [@technical], RiskCategory.available_categories(Project.find(2)).to_a
  end

  def test_shared_should_not_include_project_overrides
    override = project_override(@technical)

    assert_not_include override, RiskCategory.shared.to_a
  end
end
