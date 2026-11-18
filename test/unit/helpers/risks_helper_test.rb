require File.expand_path('../../../test_helper', __FILE__)

class RisksHelperTest < Redmine::HelperTest
  include ERB::Util
  include ApplicationHelper
  include RisksHelper
  include Rails.application.routes.url_helpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :trackers, :projects_trackers, :issue_statuses,
           :issues, :enumerations, :journals, :journal_details, :risks, :risk_issues

  def test_csv_value_should_translate_risk_values
    risk = Risk.find(1)

    assert_equal 'Low', csv_value(QueryColumn.new(:probability), risk, 25)
    assert_equal 'Moderate', csv_value(QueryColumn.new(:impact), risk, 50)
    assert_equal 'Open', csv_value(QueryColumn.new(:status), risk, 'open')
    assert_equal 'Mitigate', csv_value(QueryColumn.new(:strategy), risk, 'mitigate')
    assert_equal '', csv_value(QueryColumn.new(:probability), risk, nil)
    assert_equal '', csv_value(QueryColumn.new(:strategy), risk, nil)
    assert_equal 'Sit sodales posuere', csv_value(QueryColumn.new(:subject), risk, 'Sit sodales posuere')
  end

  def test_format_risk_status
    assert_equal 'Open', format_risk_status('open')
    assert_equal 'Closed', format_risk_status('closed')
    assert_equal 'Rejected', format_risk_status('rejected')
  end

  def test_format_risk_strategy
    assert_equal 'Accept', format_risk_strategy('accept')
    assert_equal 'Eliminate', format_risk_strategy('eliminate')
    assert_nil format_risk_strategy('invalid')
    assert_nil format_risk_strategy(nil)
  end

  def test_format_risk_probability
    assert_equal 'Unlikely', format_risk_probability(0)
    assert_equal 'Low', format_risk_probability(25)
    assert_equal 'Medium', format_risk_probability(50)
    assert_equal 'High', format_risk_probability(75)
    assert_equal 'Expected', format_risk_probability(100)
    assert_equal '30%', format_risk_probability(30)
    assert_nil format_risk_probability(nil)
  end

  def test_format_risk_impact
    assert_equal 'Negligible', format_risk_impact(0)
    assert_equal 'Moderate', format_risk_impact(50)
    assert_equal 'Severe', format_risk_impact(100)
    assert_equal '10%', format_risk_impact(10)
    assert_nil format_risk_impact(nil)
  end

  def test_format_risk_levels
    levels = format_risk_levels(Risk::RISK_IMPACT) {|i| format_risk_impact(i)}

    assert_equal [['Negligible', 0], ['Minor', 25], ['Moderate', 50], ['Significant', 75], ['Severe', 100]], levels
  end

  def test_risk_details_to_strings
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'subject', :old_value => 'Old', :value => 'New')

    assert_equal ['Subject changed from Old to New'], risk_details_to_strings([detail], true)
  end

  def test_risk_details_to_strings_should_use_unpatched_method_when_available
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'subject', :old_value => 'Old', :value => 'New')
    stubs(:details_to_strings_without_checklists).with([detail], true, {}).returns(['unpatched'])

    assert_equal ['unpatched'], risk_details_to_strings([detail], true)
  end

  def test_column_value
    risk = Risk.find(2)
    query = RiskQuery.new
    column = lambda {|name| query.available_columns.detect {|c| c.name == name}}

    assert_equal '<a href="/risks/2">2</a>', column_value(column.call(:id), risk, risk.id)
    assert_equal '<a href="/risks/2">Imperdiet nibh eleifend purus</a>', column_value(column.call(:subject), risk, risk.subject)
    assert_equal 'Medium', column_value(column.call(:probability), risk, risk.probability)
    assert_equal 'Significant', column_value(column.call(:impact), risk, risk.impact)
    assert_equal 'Closed', column_value(column.call(:status), risk, risk.status)
    assert_equal 'Transfer', column_value(column.call(:strategy), risk, risk.strategy)
    assert_include 'Fringilla nam in pellentesque', column_value(column.call(:treatments), risk, risk.treatments)
    assert_include 'Sociosqu est rutrum', column_value(column.call(:lessons), risk, risk.lessons)
    assert_equal 'eCookbook', column_value(column.call(:project), risk, risk.project).to_s.gsub(/<[^>]+>/, '')

    risk = Risk.find(1)
    assert_equal '', column_value(column.call(:lessons), risk, risk.lessons)
    risk.treatments = nil
    assert_equal '', column_value(column.call(:treatments), risk, risk.treatments)
  end

  def test_link_to_risk
    risk = Risk.find(1)

    assert_equal '<a title="Sit sodales posuere" href="/risks/1">Sit sodales posuere</a>', link_to_risk(risk)
    assert_equal '<a title="Custom" href="/risks/1">Custom</a>', link_to_risk(risk, :text => 'Custom')
  end
end
