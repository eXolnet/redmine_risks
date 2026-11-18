require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::RisksTest < Redmine::ApiTest::Base
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :trackers, :projects_trackers, :issue_statuses,
           :issues, :enumerations, :journals, :journal_details, :risks, :risk_issues

  RISK_PERMISSIONS = [:view_risks, :add_risks, :edit_risks, :delete_risks, :manage_risk_relations]

  def setup
    super
    EnabledModule.create!(:project_id => 1, :name => 'risks')
    Role.find(1).add_permission!(*RISK_PERMISSIONS)
  end

  test "GET /projects/:project_id/risks.json should return open risks" do
    get '/projects/1/risks.json', :headers => credentials('jsmith')

    assert_response :success
    assert_equal 'application/json', response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 1, json['total_count']
    assert_equal [1], json['risks'].map {|r| r['id']}

    risk = json['risks'].first
    assert_equal 'Sit sodales posuere', risk['subject']
    assert_equal 'open', risk['status']
    assert_equal 25, risk['probability']
    assert_equal 50, risk['impact']
    assert_equal 'mitigate', risk['strategy']
    assert_equal({'id' => 1, 'name' => 'eCookbook'}, risk['project'])
    assert_equal 1, risk['author']['id']
  end

  test "GET /projects/:project_id/risks.json with all statuses should return all risks" do
    get '/projects/1/risks.json?status=open%7Cclosed%7Crejected&sort=id', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 2, json['total_count']
    assert_equal [1, 2], json['risks'].map {|r| r['id']}
  end

  test "GET /projects/:project_id/risks.json should paginate" do
    get '/projects/1/risks.json?status=open%7Cclosed%7Crejected&sort=id&limit=1&offset=1', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 2, json['total_count']
    assert_equal 1, json['limit']
    assert_equal 1, json['offset']
    assert_equal [2], json['risks'].map {|r| r['id']}
  end

  test "GET /projects/:project_id/risks.xml should return risks" do
    get '/projects/1/risks.xml', :headers => credentials('jsmith')

    assert_response :success
    assert_equal 'application/xml', response.media_type
    assert_select 'risks[type=array][total_count="1"]' do
      assert_select 'risk id', :text => '1'
    end
  end

  test "GET /projects/:project_id/risks.json with invalid query should return errors" do
    get '/projects/1/risks.json?set_filter=1&f[]=created_on&op[created_on]=%3E%3D&v[created_on][]=foo',
        :headers => credentials('jsmith')

    assert_response 422
  end

  test "GET /projects/:project_id/risks.json without permission should respond with 403" do
    Role.find(1).remove_permission!(:view_risks)
    get '/projects/1/risks.json', :headers => credentials('jsmith')

    assert_response :forbidden
  end

  test "GET /projects/:project_id/risks.json without credentials should respond with 401 on private project" do
    Project.find(1).update_column(:is_public, false)
    get '/projects/1/risks.json'

    assert_response :unauthorized
  end

  test "GET /risks/:id.json should return the risk" do
    get '/risks/1.json', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 1, json['risk']['id']
    assert_equal 'Fringilla nam in pellentesque quis habitasse per', json['risk']['treatments']
    assert_nil json['risk']['issues']
    assert_nil json['risk']['journals']
  end

  test "GET /risks/:id.json?include=issues,journals should include issues and journals" do
    risk = Risk.find(1)
    risk.init_journal(User.find(2), 'Risk note')
    risk.save!

    get '/risks/1.json?include=issues,journals', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [1], json['risk']['issues'].map {|i| i['id']}
    assert_equal Issue.find(1).subject, json['risk']['issues'].first['subject']
    assert_include 'Risk note', json['risk']['journals'].map {|j| j['notes']}
  end

  test "GET /risks/:id.xml should return the risk" do
    get '/risks/2.xml', :headers => credentials('jsmith')

    assert_response :success
    assert_select 'risk' do
      assert_select 'id', :text => '2'
      assert_select 'status', :text => 'closed'
    end
  end

  test "GET /risks/:id.json with unknown id should respond with 404" do
    get '/risks/999.json', :headers => credentials('jsmith')

    assert_response :not_found
  end

  test "POST /projects/:project_id/risks.json should create the risk" do
    category = RiskCategory.create!(:name => 'Technical')

    assert_difference 'Risk.count' do
      post '/projects/1/risks.json',
           :params => {:risk => {:subject => 'API risk', :description => 'Created by API',
                                 :probability => 75, :impact => 100, :strategy => 'accept',
                                 :category_id => category.id, :assigned_to_id => 2}},
           :headers => credentials('jsmith')
    end

    assert_response :created
    risk = Risk.order(:id).last
    assert_equal 'API risk', risk.subject
    assert_equal 2, risk.author_id
    assert_equal category, risk.category
    assert_equal 'open', risk.status
    assert_equal "http://www.example.com/risks/#{risk.id}", response.headers['Location']

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal risk.id, json['risk']['id']
    assert_equal({'id' => category.id, 'name' => 'Technical'}, json['risk']['category'])
  end

  test "POST /projects/:project_id/risks.xml should create the risk" do
    assert_difference 'Risk.count' do
      post '/projects/1/risks.xml',
           :params => {:risk => {:subject => 'API risk'}},
           :headers => credentials('jsmith')
    end

    assert_response :created
    assert_select 'risk subject', :text => 'API risk'
  end

  test "POST /projects/:project_id/risks.json with invalid attributes should return errors" do
    assert_no_difference 'Risk.count' do
      post '/projects/1/risks.json',
           :params => {:risk => {:subject => 'API risk', :probability => 150, :strategy => 'foo'}},
           :headers => credentials('jsmith')
    end

    assert_response 422
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 2, json['errors'].size
  end

  test "POST /projects/:project_id/risks.json without permission should respond with 403" do
    Role.find(1).remove_permission!(:add_risks)

    assert_no_difference 'Risk.count' do
      post '/projects/1/risks.json', :params => {:risk => {:subject => 'API risk'}}, :headers => credentials('jsmith')
    end

    assert_response :forbidden
  end

  test "PUT /risks/:id.json should update the risk" do
    put '/risks/1.json',
        :params => {:risk => {:subject => 'Updated subject', :impact => 100, :notes => 'Updated by API'}},
        :headers => credentials('jsmith')

    assert_response :no_content
    risk = Risk.find(1)
    assert_equal 'Updated subject', risk.subject
    assert_equal 100, risk.impact
    assert_equal 'Updated by API', risk.journals.last.notes
  end

  test "PUT /risks/:id.json should close the risk" do
    put '/risks/1.json', :params => {:risk => {:status => 'closed'}}, :headers => credentials('jsmith')

    assert_response :no_content
    risk = Risk.find(1)
    assert_equal 'closed', risk.status
    assert risk.closed?
  end

  test "PUT /risks/:id.json with invalid status should return errors" do
    put '/risks/1.json', :params => {:risk => {:status => 'foo'}}, :headers => credentials('jsmith')

    assert_response 422
    assert_equal 'open', Risk.find(1).status
  end

  test "PUT /risks/:id.json with invalid attributes should return errors" do
    put '/risks/1.json', :params => {:risk => {:subject => ''}}, :headers => credentials('jsmith')

    assert_response 422
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 1, json['errors'].size
  end

  test "PUT /risks/:id.json without permission should respond with 403" do
    Role.find(1).remove_permission!(:edit_risks)
    put '/risks/1.json', :params => {:risk => {:subject => 'Updated'}}, :headers => credentials('jsmith')

    assert_response :forbidden
  end

  test "DELETE /risks/:id.json should delete the risk" do
    assert_difference 'Risk.count', -1 do
      delete '/risks/2.json', :headers => credentials('jsmith')
    end

    assert_response :no_content
    assert_nil Risk.find_by_id(2)
  end

  test "DELETE /risks/:id.json without permission should respond with 403" do
    Role.find(1).remove_permission!(:delete_risks)

    assert_no_difference 'Risk.count' do
      delete '/risks/2.json', :headers => credentials('jsmith')
    end

    assert_response :forbidden
  end

  test "POST /risks/:id/issues.json should link the issue" do
    post '/risks/1/issues.json', :params => {:issue_id => 2}, :headers => credentials('jsmith')

    assert_response :no_content
    assert_include Issue.find(2), Risk.find(1).issues
  end

  test "POST /risks/:id/issues.json with an already linked issue should return errors" do
    post '/risks/1/issues.json', :params => {:issue_id => 1}, :headers => credentials('jsmith')

    assert_response 422
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal ['The issue cannot be linked to this risk.'], json['errors']
  end

  test "POST /risks/:id/issues.json without permission should respond with 403" do
    Role.find(1).remove_permission!(:manage_risk_relations)
    post '/risks/1/issues.json', :params => {:issue_id => 2}, :headers => credentials('jsmith')

    assert_response :forbidden
  end

  test "DELETE /risks/:id/issues/:issue_id.json should unlink the issue" do
    delete '/risks/1/issues/1.json', :headers => credentials('jsmith')

    assert_response :no_content
    assert_not_include Issue.find(1), Risk.find(1).issues
  end

  test "DELETE /risks/:id/issues/:issue_id.json with an unlinked issue should respond with 404" do
    delete '/risks/1/issues/2.json', :headers => credentials('jsmith')

    assert_response :not_found
  end

  test "GET /enumerations/risk_categories.json should return risk categories" do
    category = RiskCategory.create!(:name => 'Technical')

    get '/enumerations/risk_categories.json', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_include({'id' => category.id, 'name' => 'Technical', 'is_default' => false, 'active' => true},
                   json['risk_categories'])
  end


  test "GET /risks/:id.json should include visible custom fields" do
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    hidden = RiskCustomField.create!(:name => 'Hidden', :field_format => 'string', :visible => false, :role_ids => [2])
    risk = Risk.find(1)
    risk.custom_field_values = {field.id.to_s => 'Ops', hidden.id.to_s => 'Secret'}
    risk.save!

    get '/risks/1.json', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [{'id' => field.id, 'name' => 'Owner team', 'value' => 'Ops'}], json['risk']['custom_fields']
  end

  test "GET /projects/:project_id/risks.json should include custom fields" do
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    risk = Risk.find(1)
    risk.custom_field_values = {field.id.to_s => 'Ops'}
    risk.save!

    get '/projects/1/risks.json', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [{'id' => field.id, 'name' => 'Owner team', 'value' => 'Ops'}], json['risks'].first['custom_fields']
  end

  test "GET /projects/:project_id/risks.json should filter on custom fields" do
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string', :is_filter => true)
    risk = Risk.find(2)
    risk.custom_field_values = {field.id.to_s => 'Ops'}
    risk.save!

    get "/projects/1/risks.json?status=open%7Cclosed%7Crejected&cf_#{field.id}=Ops", :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [2], json['risks'].map {|r| r['id']}
  end

  test "POST /projects/:project_id/risks.json should accept custom fields" do
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')

    assert_difference 'Risk.count' do
      post '/projects/1/risks.json',
           :params => {:risk => {:subject => 'API risk', :custom_fields => [{:id => field.id, :value => 'Ops'}]}},
           :headers => credentials('jsmith')
    end

    assert_response :created
    assert_equal 'Ops', Risk.order(:id).last.custom_field_value(field)
  end

  test "POST /projects/:project_id/risks.json without a required custom field should return errors" do
    RiskCustomField.create!(:name => 'Owner team', :field_format => 'string', :is_required => true)

    assert_no_difference 'Risk.count' do
      post '/projects/1/risks.json', :params => {:risk => {:subject => 'API risk'}}, :headers => credentials('jsmith')
    end

    assert_response 422
    json = ActiveSupport::JSON.decode(response.body)
    assert_include "Owner team #{::I18n.t('activerecord.errors.messages.blank')}", json['errors']
  end

  test "PUT /risks/:id.json should update custom fields and journalize the change" do
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')

    put '/risks/1.json',
        :params => {:risk => {:custom_fields => [{:id => field.id, :value => 'Ops'}]}},
        :headers => credentials('jsmith')

    assert_response :no_content
    assert_equal 'Ops', Risk.find(1).custom_field_value(field)

    get '/risks/1.json?include=journals', :headers => credentials('jsmith')
    json = ActiveSupport::JSON.decode(response.body)
    detail = json['risk']['journals'].last['details'].first
    assert_equal({'property' => 'cf', 'name' => field.id.to_s, 'old_value' => nil, 'new_value' => 'Ops'}, detail)
  end

  test "PUT /risks/:id.json should ignore custom fields not visible by the user" do
    field = RiskCustomField.create!(:name => 'Hidden', :field_format => 'string', :visible => false, :role_ids => [2])

    put '/risks/1.json',
        :params => {:risk => {:subject => 'Updated', :custom_fields => [{:id => field.id, :value => 'Secret'}]}},
        :headers => credentials('jsmith')

    assert_response :no_content
    assert_nil Risk.find(1).custom_field_value(field)
  end

  test "GET /enumerations/risk_categories.json should only return system categories" do
    technical = RiskCategory.create!(:name => 'Technical', :position => 1)
    financial = RiskCategory.create!(:name => 'Financial', :position => 2)
    Project.find(1).risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)

    get '/enumerations/risk_categories.json', :headers => credentials('jsmith')

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal [technical.id, financial.id], json['risk_categories'].map {|c| c['id']}
    assert_equal %w(Technical Financial), json['risk_categories'].map {|c| c['name']}
  end
end
