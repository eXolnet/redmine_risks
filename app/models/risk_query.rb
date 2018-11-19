class RiskQuery < Query
  include RisksHelper

  self.queried_class = Risk
  self.view_permission = :view_risks

  self.available_columns = [
    QueryColumn.new(:id, :sortable => "#{Risk.table_name}.id", :default_order => 'desc', :caption => :label_risk_id),
    QueryColumn.new(:project, :groupable => "#{Risk.table_name}.project_id", :sortable => "#{Project.table_name}.id"),
    QueryColumn.new(:subject, :sortable => "#{Risk.table_name}.subject"),
    QueryColumn.new(:category, :sortable => "#{RiskCategory.table_name}.position", :default_order => 'desc', :groupable => true),
    QueryColumn.new(:probability, :sortable => "#{Risk.table_name}.probability", :default_order => 'desc'),
    QueryColumn.new(:impact, :sortable => "#{Risk.table_name}.impact", :default_order => 'desc'),
    QueryColumn.new(:magnitude, :sortable => "(#{Risk.table_name}.impact * #{Risk.table_name}.probability)", :default_order => 'desc'),
    QueryColumn.new(:author, :sortable => lambda {User.fields_for_order_statement("authors")}, :groupable => true),
    QueryColumn.new(:assigned_to, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
    QueryColumn.new(:created_on, :sortable => "#{Risk.table_name}.created_on", :default_order => 'desc'),
    QueryColumn.new(:updated_on, :sortable => "#{Risk.table_name}.updated_on", :default_order => 'desc'),
    QueryColumn.new(:closed_on, :sortable => "#{Risk.table_name}.closed_on", :default_order => 'desc'),
    QueryColumn.new(:last_updated_by, :sortable => lambda {User.fields_for_order_statement("last_journal_user")}),
    QueryColumn.new(:description, :inline => false),
    QueryColumn.new(:treatments, :inline => false),
    QueryColumn.new(:lessons, :inline => false),
    QueryColumn.new(:last_notes, :caption => :label_last_notes, :inline => false)
  ]

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= { 'status' => {:operator => "=", :values => ["open"]} }
  end

  def initialize_available_filters
    add_available_filter"project_id", :type => :list, :values => lambda { project_values } if project.nil?
    add_available_filter "category_id", :type => :list, :values => RiskCategory.all.collect{|s| [s.name, s.id.to_s] }
    add_available_filter"author_id", :type => :list, :values => lambda { author_values }
    add_available_filter"assigned_to_id", :type => :list_optional, :values => lambda { assigned_to_values }
    add_available_filter"member_of_group", :type => :list_optional, :values => lambda { Group.givable.visible.collect {|g| [g.name, g.id.to_s] } }
    add_available_filter"assigned_to_role", :type => :list_optional, :values => lambda { Role.givable.collect {|r| [r.name, r.id.to_s] } }
    add_available_filter"status", :type => :list, :values => Risk::RISK_STATUS.map{|s| [format_risk_status(s), s] }
    add_available_filter "subject", :type => :text
    add_available_filter "description", :type => :text
    add_available_filter "created_on", :type => :date_past
    add_available_filter "updated_on", :type => :date_past
    add_available_filter "closed_on", :type => :date_past
    add_available_filter"updated_by", :type => :list, :values => lambda { author_values }
    add_available_filter"last_updated_by", :type => :list, :values => lambda { author_values }
    add_available_filter "subproject_id", :type => :list_subprojects, :values => lambda { subproject_values } if project && !project.leaf?
    add_available_filter "related_issue", :type => :relation, :label => options[:name], :values => lambda {all_projects_values}
    add_available_filter "risk_id", :type => :integer, :label => :label_risk

    add_associations_custom_fields_filters :project, :author, :assigned_to
  end

  # Returns true if the query is visible to +user+ or the current user.
  def visible?(user=User.current)
    true
  end

  def default_columns_names
    @default_columns_names = [:id, :subject, :category, :probability, :impact, :magnitude, :assigned_to, :updated_on]
  end

  def default_sort_criteria
    [['magnitude', 'desc'], ['id', 'asc']]
  end

  def base_scope
    Risk.joins(:project).where(statement)
  end

  def risk_scope(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    scope = base_scope.
      preload(:category).
      includes(([:project] + (options[:include] || [])).uniq).
      where(options[:conditions]).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      limit(options[:limit]).
      offset(options[:offset])

    scope = scope.preload([:author, :assigned_to] & columns.map(&:name))
    if has_custom_field_column?
      scope = scope.preload(:custom_values)
    end

    scope
  end

  # Returns the risk request count
  def risk_count
    base_scope.count
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the risk requests
  # Valid options are :order, :offset, :limit, :include, :conditions
  def risks(options={})
    risks = risk_scope(options).to_a

    if has_column?(:last_updated_by)
      Risk.load_visible_last_updated_by(risks)
    end
    if has_column?(:last_notes)
      Risk.load_visible_last_notes(risks)
    end

    risks
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def sql_for_updated_by_field(field, operator, value)
    neg = (operator == '!' ? 'NOT' : '')
    subquery = "SELECT 1 FROM #{Journal.table_name}" +
      " WHERE #{Journal.table_name}.journalized_type='Risk' AND #{Journal.table_name}.journalized_id=#{Risk.table_name}.id" +
      " AND (#{sql_for_field field, '=', value, Journal.table_name, 'user_id'})" +
      " AND (#{Journal.visible_notes_condition(User.current, :skip_pre_condition => true)})"

    "#{neg} EXISTS (#{subquery})"
  end

  def sql_for_last_updated_by_field(field, operator, value)
    neg = (operator == '!' ? 'NOT' : '')
    subquery = "SELECT 1 FROM #{Journal.table_name} sj" +
      " WHERE sj.journalized_type='Risk' AND sj.journalized_id=#{Risk.table_name}.id AND (#{sql_for_field field, '=', value, 'sj', 'user_id'})" +
      " AND sj.id = (SELECT MAX(#{Journal.table_name}.id) FROM #{Journal.table_name}" +
      "   WHERE #{Journal.table_name}.journalized_type='Risk' AND #{Journal.table_name}.journalized_id=#{Risk.table_name}.id" +
      "   AND (#{Journal.visible_notes_condition(User.current, :skip_pre_condition => true)}))"

    "#{neg} EXISTS (#{subquery})"
  end

  def sql_for_member_of_group_field(field, operator, value)
    if operator == '*' # Any group
      groups = Group.givable
      operator = '=' # Override the operator since we want to find by assigned_to
    elsif operator == "!*"
      groups = Group.givable
      operator = '!' # Override the operator since we want to find by assigned_to
    else
      groups = Group.where(:id => value).to_a
    end
    groups ||= []

    members_of_groups = groups.inject([]) {|user_ids, group|
      user_ids + group.user_ids + [group.id]
    }.uniq.compact.sort.collect(&:to_s)

    '(' + sql_for_field("assigned_to_id", operator, members_of_groups, Risk.table_name, "assigned_to_id", false) + ')'
  end

  def sql_for_assigned_to_role_field(field, operator, value)
    case operator
    when "*", "!*" # Member / Not member
      sw = operator == "!*" ? 'NOT' : ''
      nl = operator == "!*" ? "#{Risk.table_name}.assigned_to_id IS NULL OR" : ''
      "(#{nl} #{Risk.table_name}.assigned_to_id #{sw} IN (SELECT DISTINCT #{Member.table_name}.user_id FROM #{Member.table_name}" +
        " WHERE #{Member.table_name}.project_id = #{Risk.table_name}.project_id))"
    when "=", "!"
      role_cond = value.any? ?
                    "#{MemberRole.table_name}.role_id IN (" + value.collect{|val| "'#{self.class.connection.quote_string(val)}'"}.join(",") + ")" :
                    "1=0"

      sw = operator == "!" ? 'NOT' : ''
      nl = operator == "!" ? "#{Risk.table_name}.assigned_to_id IS NULL OR" : ''
      "(#{nl} #{Risk.table_name}.assigned_to_id #{sw} IN (SELECT DISTINCT #{Member.table_name}.user_id FROM #{Member.table_name}, #{MemberRole.table_name}" +
        " WHERE #{Member.table_name}.project_id = #{Risk.table_name}.project_id AND #{Member.table_name}.id = #{MemberRole.table_name}.member_id AND #{role_cond}))"
    end
  end

  def sql_for_risk_id_field(field, operator, value)
    if operator == "="
      # accepts a comma separated list of ids
      ids = value.first.to_s.scan(/\d+/).map(&:to_i)
      if ids.present?
        "#{Risk.table_name}.id IN (#{ids.join(",")})"
      else
        "1=0"
      end
    else
      sql_for_field("id", operator, value, Risk.table_name, "id")
    end
  end

  def sql_for_related_issue_field(field, operator, value)
    sql = case operator
      when "*", "!*"
        op = (operator == "*" ? 'IN' : 'NOT IN')
        "#{Risk.table_name}.id #{op} (SELECT DISTINCT risk_issues.risk_id FROM risk_issues)"
      when "=", "!"
        op = (operator == "=" ? 'IN' : 'NOT IN')
        "#{Risk.table_name}.id #{op} (SELECT DISTINCT risk_issues.risk_id FROM risk_issues WHERE risk_issues.issue_id = #{value.first.to_i})"
      when "=p", "=!p", "!p"
        op = (operator == "!p" ? 'NOT IN' : 'IN')
        comp = (operator == "=!p" ? '<>' : '=')
        "#{Risk.table_name}.id #{op} (SELECT DISTINCT risk_issues.risk_id FROM risk_issues, #{Issue.table_name} relissues WHERE risk_issues.issue_id = relissues.id AND relissues.project_id #{comp} #{value.first.to_i})"
      when "*o", "!o"
        op = (operator == "!o" ? 'NOT IN' : 'IN')
        "#{Risk.table_name}.id #{op} (SELECT DISTINCT risk_issues.risk_id FROM risk_issues, #{Issue.table_name} relissues WHERE risk_issues.issue_id = relissues.id AND relissues.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{self.class.connection.quoted_false}))"
      end

    "(#{sql})"
  end

  def joins_for_order_statement(order_options)
    joins = [super]

    if order_options
      if order_options.include?('authors')
        joins << "LEFT OUTER JOIN #{User.table_name} authors ON authors.id = #{queried_table_name}.author_id"
      end
      if order_options.include?('users')
        joins << "LEFT OUTER JOIN #{User.table_name} ON #{User.table_name}.id = #{queried_table_name}.assigned_to_id"
      end
      if order_options.include?('last_journal_user')
        joins << "LEFT OUTER JOIN #{Journal.table_name} ON #{Journal.table_name}.id = (SELECT MAX(#{Journal.table_name}.id) FROM #{Journal.table_name}" +
          " WHERE #{Journal.table_name}.journalized_type='Risk' AND #{Journal.table_name}.journalized_id=#{Risk.table_name}.id AND #{Journal.visible_notes_condition(User.current, :skip_pre_condition => true)})" +
          " LEFT OUTER JOIN #{User.table_name} last_journal_user ON last_journal_user.id = #{Journal.table_name}.user_id";
      end
      if order_options.include?('enumerations')
        joins << "LEFT OUTER JOIN #{RiskCategory.table_name} ON #{RiskCategory.table_name}.id = #{queried_table_name}.priority_id"
      end
    end

    joins.any? ? joins.join(' ') : nil
  end
end
