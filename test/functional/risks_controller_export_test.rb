require File.expand_path('../../test_helper', __FILE__)

class RisksControllerExportTest < ActionController::TestCase
  tests RisksController

  fixtures :projects,
           :users,
           :email_addresses,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations,
           :trackers,
           :projects_trackers,
           :issue_statuses,
           :issues,
           :journals,
           :journal_details,
           :risks,
           :risk_issues

  def setup
    @project1 = Project.find(1)
    EnabledModule.create(:project => @project1, :name => 'risks')

    @request.session[:user_id] = 1
  end

  # Index page

  def test_index_should_show_other_formats_links
    compatible_request :get, :index, :project_id => 'ecookbook'

    assert_response :success
    assert_select 'p.other-formats' do
      assert_select 'a.csv[href=?]', '/projects/ecookbook/risks.csv'
      assert_select 'a.pdf[href=?]', '/projects/ecookbook/risks.pdf'
      assert_select 'a.atom[href=?]', "/projects/ecookbook/risks.atom?key=#{User.find(1).atom_key}"
    end
    assert_select 'link[rel=alternate][type=?]', 'application/atom+xml'
  end

  def test_index_should_show_csv_export_options
    compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1,
                       :f => ['strategy'], :op => {'strategy' => '='}, :v => {'strategy' => ['mitigate']}

    assert_response :success
    assert_select '#csv-export-options form#csv-export-form[action=?]', '/projects/ecookbook/risks.csv' do
      assert_select 'input[name=?][value=?]', 'f[]', 'strategy'
      assert_select 'input[type=radio][name=?][value=?]', 'c[]', 'all_inline'
      assert_select '#csv-export-block-columns input[type=checkbox][name=?][value=?]', 'c[]', 'description'
      assert_select '#csv-export-block-columns input[type=checkbox][name=?][value=?]', 'c[]', 'lessons'
      assert_select 'select[name=?]', 'encoding'
      assert_select 'select[name=?]', 'field_separator'
    end
  end

  # CSV

  def test_index_csv
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv'

    assert_response :success
    assert_equal 'text/csv; header=present', @response.media_type
    assert_match /risks\.csv/, @response.headers['Content-Disposition']

    lines = csv_lines
    # The selected columns are exported, block columns (eg. treatments) included
    assert_equal RiskQuery.new.columns.map {|c| c.caption.to_s}, lines.first
    assert_include '1', lines.map(&:first)
    assert_not_include '2', lines.map(&:first) # closed risks are filtered out by default
  end

  def test_index_csv_should_translate_risk_values
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :set_filter => 1,
                       :f => ['status'], :op => {'status' => '*'},
                       :c => ['id', 'probability', 'impact', 'magnitude', 'strategy', 'status']

    assert_response :success
    lines = csv_lines
    assert_equal ['#', 'Probability', 'Impact', 'Magnitude', 'Strategy', 'Status'], lines.first
    assert_include ['1', 'Low', 'Moderate', 'Low', 'Mitigate', 'Open'], lines
    assert_include ['2', 'Medium', 'Significant', 'Medium', 'Transfer', 'Closed'], lines
  end

  def test_index_csv_should_use_the_language_of_the_user
    User.find(1).update!(:language => 'fr')

    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :set_filter => 1,
                       :c => ['id', 'probability', 'impact', 'magnitude', 'strategy', 'status']

    assert_response :success
    lines = csv_lines(';', 'ISO-8859-1')
    assert_equal ['#', 'Probabilité', 'Impact', 'Magnitude', 'Stratégie', 'Statut'], lines.first
    assert_include ['1', 'Basse', 'Modéré', 'Bas', 'Atténuer', 'Ouvert'], lines
  end

  def test_index_csv_should_respect_filters_and_sort
    other = Risk.create!(:project => @project1, :author => User.find(1), :subject => 'Second open risk',
                         :probability => 100, :impact => 100, :strategy => 'mitigate')

    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :set_filter => 1,
                       :f => ['status', 'strategy'], :op => {'status' => '*', 'strategy' => '='},
                       :v => {'strategy' => ['mitigate']}, :c => ['id', 'subject'], :sort => 'id:desc'

    assert_response :success
    assert_equal [other.id.to_s, '1'], csv_lines.drop(1).map(&:first)
  end

  def test_index_csv_with_all_inline_columns
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :set_filter => 1, :c => ['all_inline']

    assert_response :success
    assert_equal RiskQuery.new.available_inline_columns.size, csv_lines.first.size
  end

  def test_index_csv_with_block_columns
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :set_filter => 1,
                       :c => ['id', 'subject', 'description', 'treatments']

    assert_response :success
    lines = csv_lines
    assert_equal ['#', 'Subject', 'Description', 'Treatments'], lines.first
    assert_include ['1', 'Sit sodales posuere', 'Amet tellus quis phasellus dis ultrices nulla',
                    'Fringilla nam in pellentesque quis habitasse per'], lines
  end

  def test_index_csv_with_encoding_and_field_separator
    Risk.find(1).update_column(:subject, 'Risque élevé')

    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :set_filter => 1,
                       :c => ['id', 'subject'], :encoding => 'ISO-8859-1', :field_separator => ';'

    assert_response :success
    assert_equal Encoding::ISO_8859_1.name, @response.body.dup.force_encoding('ISO-8859-1').encoding.name
    assert_include ['1', 'Risque élevé'], csv_lines(';', 'ISO-8859-1')
  end

  def test_index_csv_filename_with_query_name
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :query_name => 'Mon registre'

    assert_response :success
    assert_match /mon_registre\.csv/, @response.headers['Content-Disposition']
  end

  def test_index_csv_should_not_change_selected_columns_in_session
    compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1, :c => ['subject', 'strategy']
    assert_equal [:subject, :strategy], session[:risk_query][:column_names]

    compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1, :c => ['all_inline'], :format => 'csv'

    assert_response :success
    assert_equal [:subject, :strategy], session[:risk_query][:column_names]
  end

  def test_index_csv_with_invalid_query
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'csv', :set_filter => 1,
                       :f => ['created_on'], :op => {'created_on' => '>='}, :v => {'created_on' => ['invalid']}

    assert_response 422
  end

  # PDF

  def test_index_pdf
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'pdf'

    assert_response :success
    assert_equal 'application/pdf', @response.media_type
    assert_match /risks\.pdf/, @response.headers['Content-Disposition']
    assert @response.body.starts_with?('%PDF')
  end

  def test_index_pdf_with_all_columns_and_block_columns
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'pdf', :set_filter => 1,
                       :f => ['status'], :op => {'status' => '*'},
                       :c => ['all_inline', 'description', 'treatments', 'lessons', 'last_notes']

    assert_response :success
    assert @response.body.starts_with?('%PDF')
  end

  def test_index_pdf_grouped
    ['strategy', 'probability', 'magnitude', 'category', 'assigned_to'].each do |group_by|
      compatible_request :get, :index, :project_id => 'ecookbook', :format => 'pdf', :set_filter => 1,
                         :f => ['status'], :op => {'status' => '*'}, :group_by => group_by

      assert_response :success, "PDF export failed when grouped by #{group_by}"
      assert @response.body.starts_with?('%PDF')
    end
  end

  def test_index_pdf_in_other_languages
    ['fr', 'zh-TW'].each do |language|
      with_settings :default_language => language do
        compatible_request :get, :index, :project_id => 'ecookbook', :format => 'pdf'

        assert_response :success
        assert @response.body.starts_with?('%PDF')
      end
    end
  end

  def test_show_pdf
    risk = Risk.find(1)
    risk.init_journal(User.find(1), 'Une note de suivi')
    risk.probability = 75
    risk.save!

    compatible_request :get, :show, :id => 1, :format => 'pdf'

    assert_response :success
    assert_equal 'application/pdf', @response.media_type
    assert_match /ecookbook-risk-1\.pdf/, @response.headers['Content-Disposition']
    assert @response.body.starts_with?('%PDF')
  end

  def test_show_should_show_other_formats_links
    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select 'p.other-formats' do
      assert_select 'a.pdf[href=?]', '/risks/1.pdf'
      assert_select 'a.atom[href=?]', "/risks/1.atom?key=#{User.find(1).atom_key}"
    end
  end

  # Atom

  def test_index_atom
    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'atom'

    assert_response :success
    assert_equal 'application/atom+xml', @response.media_type
    assert_select 'feed' do
      assert_select 'title', :text => 'eCookbook: Risks'
      assert_select 'entry link[href=?]', 'http://test.host/risks/1'
      assert_select 'entry link[href=?]', 'http://test.host/risks/2', 0
    end
  end

  def test_index_atom_with_key
    @request.session[:user_id] = nil
    Role.anonymous.remove_permission!(:view_risks)
    Role.non_member.remove_permission!(:view_risks)

    compatible_request :get, :index, :project_id => 'ecookbook', :format => 'atom', :key => User.find(1).atom_key

    assert_response :success
    assert_select 'feed entry link[href=?]', 'http://test.host/risks/1'
  end

  def test_show_atom
    risk = Risk.find(1)
    risk.init_journal(User.find(2), 'Une note de suivi')
    risk.probability = 75
    risk.save!

    compatible_request :get, :show, :id => 1, :format => 'atom'

    assert_response :success
    assert_equal 'application/atom+xml', @response.media_type
    assert_select 'feed' do
      assert_select '> title', :text => 'eCookbook - Risk #1: Sit sodales posuere'
      assert_select 'entry', 1
      assert_select 'entry link[href=?]', "http://test.host/risks/1#change-#{risk.journals.last.id}"
      assert_select 'entry author name', :text => 'John Smith'
      assert_select 'entry content', :text => /Une note de suivi/
    end
  end

  def test_show_atom_with_key
    @request.session[:user_id] = nil
    Role.anonymous.remove_permission!(:view_risks)
    Role.non_member.remove_permission!(:view_risks)

    compatible_request :get, :show, :id => 1, :format => 'atom', :key => User.find(1).atom_key

    assert_response :success
    assert_equal 'application/atom+xml', @response.media_type
  end

  def test_show_atom_without_key_should_require_login
    @request.session[:user_id] = nil
    Role.anonymous.remove_permission!(:view_risks)

    compatible_request :get, :show, :id => 1, :format => 'atom'

    assert_redirected_to "/login?back_url=#{CGI.escape('http://test.host/risks/1.atom')}"
  end

  private

  def csv_lines(separator = ',', encoding = 'UTF-8')
    body = @response.body.dup.force_encoding(encoding).encode('UTF-8').delete_prefix("\uFEFF")
    CSV.parse(body, :col_sep => separator)
  end
end
