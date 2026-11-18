require File.expand_path('../../test_helper', __FILE__)

class ProjectPatchTest < ActiveSupport::TestCase
  fixtures :projects, :users, :enabled_modules, :enumerations, :risks

  def setup
    @project = Project.find(1)
    @technical = RiskCategory.create!(:name => 'Technical', :position => 1)
    @financial = RiskCategory.create!(:name => 'Financial', :position => 2)
    @legacy = RiskCategory.create!(:name => 'Legacy', :position => 3, :active => false)
    Risk.where(:id => [1, 2]).update_all(:category_id => @technical.id)
  end

  def test_risk_categories_available_should_return_active_system_categories
    assert_equal [@technical, @financial], @project.risk_categories_available.to_a
    assert_equal [@technical, @financial, @legacy], @project.risk_categories_available(true).to_a
  end

  def test_update_or_create_risk_categories_should_create_inactive_override
    assert_difference 'RiskCategory.count' do
      @project.update_or_create_risk_categories(
        @technical.id.to_s => {'parent_id' => @technical.id.to_s, 'active' => '0'},
        @financial.id.to_s => {'parent_id' => @financial.id.to_s, 'active' => '1'}
      )
    end

    override = @project.risk_categories.first
    assert_equal @technical, override.parent
    assert_equal 'Technical', override.name
    assert_equal @technical.position, override.position
    assert_not override.active?
    assert override.is_override?

    assert_equal [@financial], @project.risk_categories_available.to_a
    assert_equal [@technical, @financial], Project.find(2).risk_categories_available.to_a
  end

  def test_creating_override_should_move_project_risks_and_keep_their_category
    @project.update_or_create_risk_categories(
      @technical.id.to_s => {'parent_id' => @technical.id.to_s, 'active' => '0'}
    )
    override = @project.risk_categories.first

    assert_equal [override.id], Risk.where(:id => [1, 2]).distinct.pluck(:category_id)
    assert_equal 'Technical', Risk.find(1).category.name
  end

  def test_unchanged_system_category_should_not_create_override
    assert_no_difference 'RiskCategory.count' do
      @project.update_or_create_risk_categories(
        @technical.id.to_s => {'parent_id' => @technical.id.to_s, 'active' => '1'}
      )
    end
  end

  def test_update_or_create_risk_categories_should_update_existing_override
    @project.update_or_create_risk_categories(
      @technical.id.to_s => {'parent_id' => @technical.id.to_s, 'active' => '0'}
    )
    override = @project.risk_categories.first

    assert_no_difference 'RiskCategory.count' do
      @project.update_or_create_risk_categories(override.id.to_s => {'active' => '1'})
    end
    assert override.reload.active?
    assert_equal [override, @financial], @project.risk_categories_available.to_a
  end

  def test_activating_system_inactive_category_in_project
    @project.update_or_create_risk_categories(
      @legacy.id.to_s => {'parent_id' => @legacy.id.to_s, 'active' => '1'}
    )

    assert_include 'Legacy', @project.risk_categories_available.map(&:name)
    assert_not_include 'Legacy', Project.find(2).risk_categories_available.map(&:name)
  end

  def test_destroying_project_should_delete_risk_categories
    @project.update_or_create_risk_categories(
      @technical.id.to_s => {'parent_id' => @technical.id.to_s, 'active' => '0'}
    )
    project = Project.find(2)
    override = project.risk_categories.create!(:name => 'Technical', :parent => @technical, :active => false)

    project.destroy

    assert_nil RiskCategory.find_by_id(override.id)
  end

  # Categories specific to a project

  def test_project_specific_category_should_be_available_after_system_categories
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    assert regulatory.project_specific?
    assert_not regulatory.is_override?
    assert_equal [@technical, @financial, regulatory], @project.risk_categories_available.to_a
    assert_not_include regulatory, Project.find(2).risk_categories_available.to_a
    assert_not_include regulatory, RiskCategory.shared.to_a
  end

  def test_project_specific_category_should_not_take_the_name_of_a_system_category
    category = @project.risk_categories.build(:name => 'technical')

    assert_not category.valid?
    assert_include :name, category.errors.attribute_names
  end

  def test_project_specific_category_name_should_be_unique_in_project
    @project.risk_categories.create!(:name => 'Regulatory')

    assert_not @project.risk_categories.build(:name => 'Regulatory').valid?
    assert Project.find(2).risk_categories.build(:name => 'Regulatory').valid?
  end

  def test_update_or_create_risk_categories_should_rename_and_disable_project_specific_category
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    assert @project.update_or_create_risk_categories(
      regulatory.id.to_s => {'name' => 'Compliance', 'active' => '0'}
    )
    regulatory.reload
    assert_equal 'Compliance', regulatory.name
    assert_not regulatory.active?
    assert_not_include regulatory, @project.risk_categories_available.to_a
  end

  def test_update_or_create_risk_categories_should_not_rename_overrides
    @project.update_or_create_risk_categories(
      @technical.id.to_s => {'parent_id' => @technical.id.to_s, 'active' => '0'}
    )
    override = @project.risk_categories.first

    assert @project.update_or_create_risk_categories(override.id.to_s => {'name' => 'Other', 'active' => '1'})
    assert_equal 'Technical', override.reload.name
    assert override.active?
  end

  def test_update_or_create_risk_categories_with_invalid_name_should_rollback
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    assert_not @project.update_or_create_risk_categories(
      @technical.id.to_s => {'parent_id' => @technical.id.to_s, 'active' => '0'},
      regulatory.id.to_s => {'name' => '', 'active' => '1'}
    )
    assert_equal regulatory, @project.invalid_risk_category
    assert_equal 'Regulatory', regulatory.reload.name
    assert_equal [regulatory], @project.risk_categories.reload.to_a
  end

  def test_project_specific_categories_should_be_ordered_by_position_after_system_categories
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    compliance = @project.risk_categories.create!(:name => 'Compliance')
    assert_equal [1, 2], [regulatory.position, compliance.position]

    compliance.update!(:position => 1)

    assert_equal [@technical, @financial, compliance, regulatory], @project.risk_categories_available.to_a
    assert_equal 2, regulatory.reload.position
    assert_equal [1, 2, 3], [@technical, @financial, @legacy].map {|c| c.reload.position}
  end

  def test_risk_categories_should_be_sorted_with_system_categories_first
    regulatory = @project.risk_categories.create!(:name => 'Regulatory') # position 1
    override = @project.risk_categories.create!(:name => 'Financial', :parent => @financial, :active => false)

    assert_equal [@technical, @financial, override, regulatory], [regulatory, override, @financial, @technical].sort
  end
end
