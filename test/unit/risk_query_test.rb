require File.expand_path('../../test_helper', __FILE__)

class RiskQueryTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :groups_users, :roles, :members, :member_roles,
           :enabled_modules, :trackers, :projects_trackers, :issue_statuses,
           :issues, :enumerations, :journals, :journal_details, :risks, :risk_issues

  def setup
    User.current = User.find(1) # admin
    @project = Project.find(1)
    EnabledModule.create!(:project => @project, :name => 'risks')
  end

  def teardown
    User.current = nil
  end

  def build_query(filters = {}, options = {})
    query = RiskQuery.new(:name => '_', :project => options.key?(:project) ? options[:project] : @project)
    query.filters = {}
    filters.each do |field, (operator, values)|
      query.add_filter(field, operator, values)
    end
    query.sort_criteria = options[:sort] if options[:sort]
    query.group_by = options[:group_by] if options[:group_by]
    query.column_names = options[:columns] if options[:columns]
    query
  end

  def risk_ids(query)
    query.risks.map(&:id).sort
  end

  def add_journal(risk, user, notes = '', private_notes = false)
    journal = Journal.new(:journalized => risk, :user => user, :notes => notes, :private_notes => private_notes)
    journal.notify = false
    journal.save!
    journal
  end

  def test_default_filter_should_return_open_risks_only
    query = RiskQuery.new(:name => '_', :project => @project)

    assert_equal({'status' => {:operator => '=', :values => ['open']}}, query.filters)
    assert_equal [1], risk_ids(query)
    assert_equal 1, query.risk_count
  end

  def test_project_filter_should_only_be_available_without_project
    assert_nil build_query.available_filters['project_id']
    assert_not_nil build_query({}, :project => nil).available_filters['project_id']
  end

  def test_query_should_be_visible_to_anyone
    assert build_query.visible?(User.anonymous)
  end

  def test_status_filter
    assert_equal [2], risk_ids(build_query('status' => ['=', ['closed']]))
    assert_equal [1, 2], risk_ids(build_query('status' => ['=', ['open', 'closed']]))
  end

  def test_strategy_filter
    assert_equal [2], risk_ids(build_query('strategy' => ['=', ['transfer']]))
  end

  def test_probability_and_impact_filters_should_list_risk_levels
    query = build_query

    assert_equal %w(0 25 50 75 100), query.available_filters['probability'][:values].map(&:last)
    assert_equal 'Low', query.available_filters['probability'][:values][1].first
    assert_equal %w(0 25 50 75 100), query.available_filters['impact'][:values].map(&:last)
    assert_equal 'Significant', query.available_filters['impact'][:values][3].first
  end

  def test_probability_filter
    assert_equal [1], risk_ids(build_query('probability' => ['=', ['25']]))
    assert_equal [1, 2], risk_ids(build_query('probability' => ['=', ['25', '50']]))
    assert_equal [2], risk_ids(build_query('probability' => ['!', ['25']]))
  end

  def test_impact_filter
    assert_equal [2], risk_ids(build_query('impact' => ['=', ['75']]))
    assert_equal [], risk_ids(build_query('impact' => ['=', ['100']]))
  end

  def test_probability_and_impact_filters_combined
    assert_equal [1], risk_ids(build_query('probability' => ['=', ['25']], 'impact' => ['=', ['50']]))
    assert_equal [], risk_ids(build_query('probability' => ['=', ['25']], 'impact' => ['=', ['75']]))
  end

  def test_updated_by_filter
    add_journal(Risk.find(1), User.find(2), 'Note by jsmith')
    add_journal(Risk.find(2), User.find(3), 'Note by dlopper')

    assert_equal [1], risk_ids(build_query('updated_by' => ['=', ['2']]))
    assert_equal [2], risk_ids(build_query('updated_by' => ['!', ['2']]))
  end

  def test_last_updated_by_filter
    risk = Risk.find(1)
    add_journal(risk, User.find(2), 'First')
    add_journal(risk, User.find(3), 'Last')

    assert_equal [], risk_ids(build_query('last_updated_by' => ['=', ['2']]))
    assert_equal [1], risk_ids(build_query('last_updated_by' => ['=', ['3']]))
    assert_equal [1, 2], risk_ids(build_query('last_updated_by' => ['!', ['2']]))
  end

  def test_member_of_group_filter
    Risk.find(1).update_column(:assigned_to_id, 8) # member of groups 10 and 11
    Risk.find(2).update_column(:assigned_to_id, 10) # group A Team

    assert_equal [1, 2], risk_ids(build_query('member_of_group' => ['=', ['10']]))
    assert_equal [1], risk_ids(build_query('member_of_group' => ['=', ['11']]))
    assert_equal [1, 2], risk_ids(build_query('member_of_group' => ['*']))

    Risk.find(2).update_column(:assigned_to_id, 3)
    assert_equal [2], risk_ids(build_query('member_of_group' => ['!*']))
  end

  def test_assigned_to_role_filter
    Risk.find(1).update_column(:assigned_to_id, 2) # Manager on project 1
    Risk.find(2).update_column(:assigned_to_id, 3) # Developer on project 1

    assert_equal [1], risk_ids(build_query('assigned_to_role' => ['=', ['1']]))
    assert_equal [2], risk_ids(build_query('assigned_to_role' => ['!', ['1']]))
    assert_equal [1, 2], risk_ids(build_query('assigned_to_role' => ['*']))

    Risk.find(2).update_column(:assigned_to_id, nil)
    assert_equal [2], risk_ids(build_query('assigned_to_role' => ['!*']))
  end

  def test_assigned_to_role_filter_without_values_should_match_nothing
    query = build_query
    assert_equal '( risks.assigned_to_id  IN (SELECT DISTINCT members.user_id FROM members, member_roles' +
                 ' WHERE members.project_id = risks.project_id AND members.id = member_roles.member_id AND 1=0))',
                 query.sql_for_assigned_to_role_field('assigned_to_role', '=', [])
  end

  def test_risk_id_filter
    assert_equal [2], risk_ids(build_query('risk_id' => ['=', ['2']]))
    assert_equal [1, 2], risk_ids(build_query('risk_id' => ['=', ['1,2']]))
    assert_equal [2], risk_ids(build_query('risk_id' => ['>=', ['2']]))
    assert_not build_query('risk_id' => ['=', ['abc']]).valid?
    assert_equal '1=0', build_query.sql_for_risk_id_field('risk_id', '=', [''])
  end

  def test_related_issue_filter
    # Risk 1 is related to issue 1 (project 1, open status)
    assert_equal [1], risk_ids(build_query('related_issue' => ['*']))
    assert_equal [2], risk_ids(build_query('related_issue' => ['!*']))
    assert_equal [1], risk_ids(build_query('related_issue' => ['=', ['1']]))
    assert_equal [2], risk_ids(build_query('related_issue' => ['!', ['1']]))
    assert_equal [1], risk_ids(build_query('related_issue' => ['=p', ['1']]))
    assert_equal [], risk_ids(build_query('related_issue' => ['=!p', ['1']]))
    assert_equal [2], risk_ids(build_query('related_issue' => ['!p', ['1']]))
    assert_equal [1], risk_ids(build_query('related_issue' => ['*o']))
    assert_equal [2], risk_ids(build_query('related_issue' => ['!o']))
  end

  def test_sort_by_each_sortable_column
    RiskQuery.available_columns.select(&:sortable?).each do |column|
      %w(asc desc).each do |direction|
        query = build_query({}, :sort => [[column.name.to_s, direction]])
        assert_equal [1, 2], risk_ids(query), "Sorting by #{column.name} #{direction} failed"
      end
    end
  end

  def test_sort_by_category
    low = RiskCategory.create!(:name => 'Low', :position => 1)
    high = RiskCategory.create!(:name => 'High', :position => 2)
    Risk.find(1).update_column(:category_id, low.id)
    Risk.find(2).update_column(:category_id, high.id)

    assert_equal [1, 2], build_query({}, :sort => [['category', 'asc']]).risks.map(&:id)
    assert_equal [2, 1], build_query({}, :sort => [['category', 'desc']]).risks.map(&:id)
  end

  def test_sort_by_assigned_to_and_author
    Risk.find(1).update_column(:assigned_to_id, 3) # Dave Lopper
    Risk.find(2).update_column(:assigned_to_id, 2) # John Smith

    with_settings :user_format => 'firstname_lastname' do
      assert_equal [1, 2], build_query({}, :sort => [['assigned_to', 'asc']]).risks.map(&:id)
      assert_equal [2, 1], build_query({}, :sort => [['assigned_to', 'desc']]).risks.map(&:id)
    end
  end

  def test_sort_by_last_updated_by
    add_journal(Risk.find(1), User.find(3), 'By Dave')
    add_journal(Risk.find(2), User.find(2), 'By John')

    with_settings :user_format => 'firstname_lastname' do
      assert_equal [1, 2], build_query({}, :sort => [['last_updated_by', 'asc']]).risks.map(&:id)
      assert_equal [2, 1], build_query({}, :sort => [['last_updated_by', 'desc']]).risks.map(&:id)
    end
  end

  def test_group_by_each_groupable_column
    RiskQuery.available_columns.select(&:groupable?).each do |column|
      query = build_query({}, :group_by => column.name.to_s)
      assert query.grouped?, "Query should be grouped by #{column.name}"
      assert_equal [1, 2], risk_ids(query), "Grouping by #{column.name} failed"
    end
  end

  def test_risk_levels_should_be_groupable
    query = build_query
    %w(probability impact magnitude strategy).each do |name|
      assert_include name, query.groupable_columns.map {|c| c.name.to_s }
    end
  end

  def test_group_by_probability_and_impact_should_count_by_value
    assert_equal({50 => 1, 25 => 1}, build_query({}, :group_by => 'probability').result_count_by_group)
    assert_equal({75 => 1, 50 => 1}, build_query({}, :group_by => 'impact').result_count_by_group)
  end

  def test_group_by_magnitude_should_count_by_level
    Risk.create!(:project => @project, :author => User.find(1), :subject => 'Unrated', :probability => nil, :impact => nil)
    Risk.create!(:project => @project, :author => User.find(1), :subject => 'Extreme', :probability => 100, :impact => 100)

    query = build_query({}, :group_by => 'magnitude')
    assert_equal({3 => 1, 1 => 1, 0 => 1, nil => 1}, query.result_count_by_group)

    risks = query.risks
    levels = risks.map(&:magnitude_level).uniq
    assert_equal 4, levels.size, 'Risks of the same level should be contiguous'
    assert_equal [3, 1, 0], levels.compact
    assert_equal risks.map(&:magnitude_level), risks.map {|risk| query.group_by_column.group_value(risk)}
  end

  def test_risks_should_preload_last_updated_by_and_last_notes
    risk = Risk.find(1)
    add_journal(risk, User.find(2), 'Visible note')
    add_journal(risk, User.find(3), '')

    query = build_query({}, :columns => [:subject, :last_updated_by, :last_notes])
    risks = query.risks.index_by(&:id)

    assert_equal User.find(3), risks[1].last_updated_by
    assert_equal 'Visible note', risks[1].last_notes
    assert_nil risks[2].last_updated_by
    assert_equal '', risks[2].last_notes
  end

  def test_risks_should_raise_statement_invalid_on_sql_error
    query = build_query
    query.stubs(:statement).returns('invalid sql statement')

    assert_raise(Query::StatementInvalid) { query.risks }
    assert_raise(Query::StatementInvalid) { query.risk_count }
  end

  def test_filters_and_columns_should_be_translated
    %w(en fr de pt-BR pt zh-TW).each do |locale|
      ::I18n.with_locale(locale) do
        query = build_query
        labels = query.available_filters.values.map {|f| f[:name].to_s } +
                 query.available_columns.map {|c| c.caption.to_s }

        labels.each do |label|
          assert_not_include "Translation missing", label, "Missing translation for #{locale}"
        end
      end
    end
  end


  def test_risk_custom_field_should_be_available_as_column_filter_and_group
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'list',
                                    :possible_values => ['Dev', 'Ops'], :is_filter => true)
    query = build_query

    column = query.available_columns.detect {|c| c.name == "cf_#{field.id}".to_sym}
    assert_kind_of QueryCustomFieldColumn, column
    assert column.sortable
    assert column.groupable?
    assert_not_nil query.available_filters["cf_#{field.id}"]
  end

  def test_risk_custom_field_not_flagged_as_filter_should_not_be_a_filter
    field = RiskCustomField.create!(:name => 'Notes', :field_format => 'string', :is_filter => false)

    assert_nil build_query.available_filters["cf_#{field.id}"]
  end

  def test_filter_on_risk_custom_field
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'list',
                                    :possible_values => ['Dev', 'Ops'], :is_filter => true)
    risk = Risk.find(2)
    risk.custom_field_values = {field.id.to_s => 'Ops'}
    risk.save!

    query = build_query("cf_#{field.id}" => ['=', ['Ops']])
    assert_equal [2], risk_ids(query)

    query = build_query("cf_#{field.id}" => ['!*', ['']])
    assert_equal [1], risk_ids(query)
  end

  def test_group_and_sort_by_risk_custom_field
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'list',
                                    :possible_values => ['Dev', 'Ops'])
    {1 => 'Ops', 2 => 'Dev'}.each do |id, value|
      risk = Risk.find(id)
      risk.custom_field_values = {field.id.to_s => value}
      risk.save!
    end

    query = build_query({'status' => ['*', ['']]},
                        :group_by => "cf_#{field.id}", :sort => [["cf_#{field.id}", 'asc']],
                        :columns => [:id, :subject, "cf_#{field.id}".to_sym])

    assert query.grouped?
    assert_equal [2, 1], query.risks.map(&:id)
    assert_equal({'Dev' => 1, 'Ops' => 1}, query.result_count_by_group.transform_keys(&:to_s))
  end

  def test_risk_custom_field_restricted_to_roles_should_be_hidden_from_other_users
    Role.find(1).add_permission!(:view_risks)
    Role.find(2).add_permission!(:view_risks)
    field = RiskCustomField.create!(:name => 'Managers only', :field_format => 'string', :is_filter => true,
                                    :visible => false, :role_ids => [1])

    User.current = User.find(2) # Manager
    assert build_query.available_columns.any? {|c| c.name == "cf_#{field.id}".to_sym}
    assert_not_nil build_query.available_filters["cf_#{field.id}"]

    User.current = User.find(3) # Developer
    assert build_query.available_columns.none? {|c| c.name == "cf_#{field.id}".to_sym}
    assert_nil build_query.available_filters["cf_#{field.id}"]
  end
end
