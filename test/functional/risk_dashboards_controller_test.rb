require File.expand_path('../../test_helper', __FILE__)

# Tests the project risk dashboard as a regular project member (jsmith, Manager on eCookbook)
class RiskDashboardsControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :email_addresses,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations,
           :issues,
           :risks,
           :risk_issues

  def setup
    @project = Project.find(1)
    EnabledModule.create!(:project => @project, :name => 'risks')
    @role = Role.find(1)
    @role.add_permission!(:view_risks)

    @request.session[:user_id] = 2 # jsmith, Manager on project 1
  end

  def create_risk(attributes = {})
    Risk.create!({:project => @project, :author => User.find(2), :subject => 'Risk'}.merge(attributes))
  end

  def matrix_cell(probability, impact)
    "table.risk-matrix td[data-probability='#{probability}'][data-impact='#{impact}']"
  end

  def show
    compatible_request :get, :show, :project_id => 'ecookbook'
    assert_response :success
  end

  # Access

  def test_show_without_view_permission_should_be_denied
    @role.remove_permission!(:view_risks)

    compatible_request :get, :show, :project_id => 'ecookbook'

    assert_response 403
  end

  def test_show_with_risks_module_disabled_should_be_denied
    EnabledModule.where(:project_id => @project.id, :name => 'risks').delete_all

    compatible_request :get, :show, :project_id => 'ecookbook'

    assert_response 403
  end

  def test_show_as_anonymous_without_permission_should_require_login
    @request.session[:user_id] = nil

    compatible_request :get, :show, :project_id => 'ecookbook'

    assert_response 302
    assert_match %r{/login}, response.location
  end

  def test_show_with_unknown_project_should_respond_404
    compatible_request :get, :show, :project_id => 'unknown'

    assert_response 404
  end

  def test_show_should_highlight_the_risks_menu_and_link_to_the_list
    show

    assert_select '#main-menu a.risks.selected'
    assert_select '.contextual a[href=?]', '/projects/ecookbook/risks'
  end

  # Matrix

  def test_show_should_render_a_5x5_matrix
    show

    assert_select 'table.risk-matrix thead th', 6
    assert_select 'table.risk-matrix tbody tr', 5
    assert_select 'table.risk-matrix tbody td', 25
    assert_select 'table.risk-matrix tbody tr:first-child th', :text => 'Expected'
    assert_select 'table.risk-matrix thead th:last-child', :text => 'Severe'
  end

  def test_show_should_count_open_risks_by_probability_and_impact
    create_risk(:probability => 25, :impact => 50)

    show

    assert_select matrix_cell(25, 50), :text => '2'
    # Risk #2 is closed and must not be counted
    assert_select matrix_cell(50, 75), :text => ''
    assert_select "#{matrix_cell(50, 75)}.empty"
    assert_select 'table.risk-matrix td:not(.empty)', 1
  end

  def test_show_should_color_matrix_cells_by_magnitude
    show

    assert_select "#{matrix_cell(25, 50)}.magnitude-low"
    assert_select "#{matrix_cell(50, 50)}.magnitude-medium"
    assert_select "#{matrix_cell(75, 75)}.magnitude-high"
    assert_select "#{matrix_cell(100, 100)}.magnitude-extreme"
    assert_select 'table.risk-matrix td.magnitude-low', 14
    assert_select 'table.risk-matrix td.magnitude-extreme', 3
    assert_select 'ul.risk-magnitude-legend li', 4
  end

  def test_matrix_cell_should_link_to_the_filtered_risk_list
    show

    assert_select "#{matrix_cell(25, 50)} a" do |links|
      uri = URI.parse(links.first['href'])
      params = Rack::Utils.parse_nested_query(uri.query)

      assert_equal '/projects/ecookbook/risks', uri.path
      assert_equal '1', params['set_filter']
      assert_equal %w(status probability impact), params['f'].reject(&:blank?)
      assert_equal({'status' => '=', 'probability' => '=', 'impact' => '='}, params['op'])
      assert_equal({'status' => ['open'], 'probability' => ['25'], 'impact' => ['50']}, params['v'])
    end
    assert_select "#{matrix_cell(25, 50)} a[title*=?]", 'Probability: Low, impact: Moderate, magnitude: Low'
  end

  def test_show_should_mention_open_risks_not_rated_on_the_matrix
    create_risk(:probability => nil, :impact => 50)
    create_risk(:probability => 30, :impact => 50)

    show

    assert_select 'p.risk-unrated', :text => '2 open risks are not rated on the matrix'
  end

  def test_show_should_not_mention_unrated_risks_when_all_are_rated
    show

    assert_select 'p.risk-unrated', 0
  end

  def test_show_should_include_subproject_risks
    subproject = Project.find(3)
    EnabledModule.create!(:project => subproject, :name => 'risks')
    create_risk(:project => subproject, :probability => 25, :impact => 50)

    with_settings :display_subprojects_issues => '1' do
      show
    end

    assert_select matrix_cell(25, 50), :text => '2'
  end

  # Counters

  def test_show_should_display_counters_by_status
    create_risk(:status => 'rejected')

    show

    assert_select 'li.status-open .count', :text => '1'
    assert_select 'li.status-closed .count', :text => '1'
    assert_select 'li.status-rejected .count', :text => '1'
    assert_select 'li.status-closed a[href*=?]', 'v%5Bstatus%5D%5B%5D=closed'
  end

  def test_show_should_not_count_risks_of_other_projects
    create_risk(:project => Project.find(2), :probability => 25, :impact => 50)

    show

    assert_select 'li.status-open .count', :text => '1'
    assert_select matrix_cell(25, 50), :text => '1'
  end

  # Top risks

  def test_show_should_list_the_top_5_open_risks_by_magnitude
    low = create_risk(:probability => 25, :impact => 25)
    extreme = create_risk(:probability => 100, :impact => 100)
    high = create_risk(:probability => 75, :impact => 75)
    medium = create_risk(:probability => 50, :impact => 75)
    medium_tied = create_risk(:probability => 75, :impact => 50)
    create_risk(:probability => 100, :impact => 100, :status => 'closed')
    create_risk(:probability => nil, :impact => nil)

    show

    assert_select '.risk-top-risks tbody tr', 5
    ids = css_select('.risk-top-risks tbody tr').map {|tr| tr['id'].delete_prefix('top-risk-').to_i }
    assert_equal [extreme.id, high.id, medium.id, medium_tied.id, 1], ids
    assert_not_includes ids, low.id
    assert_select "tr#top-risk-#{extreme.id} .risk-magnitude-badge.magnitude-extreme", :text => 'Extreme'
    assert_select "tr#top-risk-#{extreme.id} td.subject a[href=?]", "/risks/#{extreme.id}"
  end

  def test_show_without_open_risks_should_display_no_data
    Risk.find(1).update!(:status => 'closed')

    show

    assert_select '.risk-top-risks p.nodata'
    assert_select '.risk-by-category p.nodata'
    assert_select '.risk-by-strategy p.nodata'
    assert_select 'table.risk-matrix td:not(.empty)', 0
  end

  # Breakdowns

  def test_show_should_display_open_risks_by_category
    technical = RiskCategory.create!(:name => 'Technical')
    external = RiskCategory.create!(:name => 'External')
    Risk.find(1).update_column(:category_id, technical.id)
    create_risk(:category_id => technical.id)
    create_risk(:category_id => external.id)
    create_risk(:category_id => nil)

    show

    assert_select ".risk-by-category tr.category-#{technical.id}" do
      assert_select 'td.name', :text => 'Technical'
      assert_select 'td.count a', :text => '2'
      assert_select 'td.count a[href*=?]', "v%5Bcategory_id%5D%5B%5D=#{technical.id}"
      assert_select '.risk-bar[style=?]', 'width: 50%'
    end
    assert_select ".risk-by-category tr.category-#{external.id} td.count", :text => '1'
    assert_select '.risk-by-category tr.category-none td.count', :text => '1'
    assert_select '.risk-by-category tr.category-none td.count a', 0
  end

  def test_show_should_display_open_risks_by_strategy
    create_risk(:strategy => 'accept')
    create_risk(:strategy => 'mitigate')
    create_risk(:strategy => nil)

    show

    assert_select '.risk-by-strategy tbody tr', 3
    assert_select '.risk-by-strategy tbody tr:first-child td.name', :text => 'Accept'
    assert_select '.risk-by-strategy tr.strategy-mitigate td.count a', :text => '2'
    assert_select '.risk-by-strategy tr.strategy-mitigate td.count a[href*=?]', 'v%5Bstrategy%5D%5B%5D=mitigate'
    assert_select '.risk-by-strategy tr.strategy-none td.count', :text => '1'
    # Risk #2 is closed
    assert_select '.risk-by-strategy tr.strategy-transfer', 0
  end

  def test_show_should_count_project_overrides_with_their_system_category
    technical = RiskCategory.create!(:name => 'Technical')
    override = @project.risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)
    Risk.find(1).update_column(:category_id, override.id)
    # A risk still referencing the system category (eg. created before the override)
    create_risk.update_column(:category_id, technical.id)

    show

    assert_select '.risk-by-category tr', 1
    assert_select ".risk-by-category tr.category-#{technical.id}" do
      assert_select 'td.name', :text => 'Technical'
      assert_select 'td.count a', :text => '2'
      assert_select 'td.count a[href*=?]', "v%5Bcategory_id%5D%5B%5D=#{technical.id}"
    end
  end
end
