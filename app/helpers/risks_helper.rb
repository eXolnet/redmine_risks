module RisksHelper
  include IssuesHelper
  include QueriesHelper

  def find_risk
    risk_id = params[:risk_id] || params[:id]

    @risk = Risk.find(risk_id)
    raise Unauthorized unless @risk.visible?
    @project = @risk.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_risks
    @risks = Risk
      .where(:id => (params[:id] || params[:ids]))
      .preload(:project, :author, :assigned_to)
      .to_a

    raise ActiveRecord::RecordNotFound if @risks.empty?
    raise Unauthorized unless @risks.all?(&:visible?)

    @projects = @risks.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def format_risk_status(status)
    l("label_risk_status_#{status}")
  end

  def format_risk_probability(probability)
    format_risk_level(Risk::RISK_PROBABILITY, probability) {|p| l("label_risk_probability_#{p}")}
  end

  def format_risk_impact(impact)
    format_risk_level(Risk::RISK_IMPACT, impact) {|i| l("label_risk_impact_#{i}")}
  end

  def format_risk_strategy(strategy)
    return unless Risk::RISK_STRATEGY.include?(strategy)
    l("label_risk_strategy_#{strategy}")
  end

  def format_risk_level(levels, level, &block)
    return if level.nil?

    increment = 100 / (levels.count - 1)

    if level % increment != 0
      return level.to_s + "%"
    end

    yield levels[level / increment]
  end

  def format_risk_levels(levels, value = nil, &block)
    index     = 0
    increment = 100 / (levels.count - 1)

    levels.collect do |level|
      value  = index * increment
      index += 1

      [yield(value), value]
    end
  end

  def render_risk_relations(risk)
    manage_relations = User.current.allowed_to?(:manage_risk_relations, risk.project)

    relations = risk.issues.visible.collect do |issue|
      delete_link = link_to(l(:label_relation_delete),
                            {:controller => 'risk_issues', :action => 'destroy_by_risk', :risk_id => @risk, :issue_id => issue},
                            :remote => true,
                            :method => :delete,
                            :data => {:confirm => l(:text_are_you_sure)},
                            :title => l(:label_relation_delete),
                            :class => 'icon-only icon-link-break')

      relation = ''.html_safe

      relation << content_tag('td', check_box_tag("ids[]", issue.id, false, :id => nil), :class => 'checkbox')
      relation << content_tag('td', link_to_issue(issue, :project => Setting.cross_project_issue_relations?).html_safe, :class => 'subject', :style => 'width: 50%')
      relation << content_tag('td', issue.status, :class => 'status')
      relation << content_tag('td', issue.start_date, :class => 'start_date')
      relation << content_tag('td', issue.due_date, :class => 'due_date')
      relation << content_tag('td', progress_bar(issue.done_ratio), :class=> 'done_ratio') unless issue.disabled_core_fields.include?('done_ratio')
      relation << content_tag('td', delete_link, :class => 'buttons') if manage_relations

      content_tag('tr', relation, :id => "relation-#{issue.id}", :class => "issue hascontextmenu #{issue.css_classes}")
    end

    content_tag('table', relations.join.html_safe, :class => 'list issues odd-even')
  end

  def render_risks_relations(issue)
    manage_relations = User.current.allowed_to?(:manage_risk_relations, issue.project)

    relations = issue.risks.collect do |risk|
      delete_link = link_to(l(:label_relation_delete),
                            {:controller => 'risk_issues', :action => 'destroy_by_issue', :risk_id => risk.id, :issue_id => issue.id},
                            :remote => true,
                            :method => :delete,
                            :data => {:confirm => l(:text_are_you_sure)},
                            :title => l(:label_relation_delete),
                            :class => 'icon-only icon-link-break')
      relation = ''.html_safe

      relation << content_tag('td', check_box_tag("ids[]", risk.id, false, :id => nil), :class => 'checkbox')
      relation << content_tag('td', format_risk_status(risk.status), :class => 'status')
      relation << content_tag('td', link_to(risk.project.name, project_path(risk.project)).html_safe, :class => 'project')
      relation << content_tag('td', link_to(risk.subject, risk_path(risk)).html_safe, :class => 'subject', :style => 'width: 50%')
      relation << content_tag('td', risk.category ? risk.category.name : "-", :class => 'category')
      relation << content_tag('td', risk.probability.present? ? format_risk_probability(risk.probability) : "-", :class => 'probability')
      relation << content_tag('td', risk.impact.present? ? format_risk_impact(risk.impact) : "-", :class => 'impact')
      relation << content_tag('td', risk.magnitude.present? ? risk.magnitude : "-", :class => 'magnitude')
      relation << content_tag('td', risk.strategy.present? ? format_risk_strategy(risk.strategy) : "-", :class => 'strategy')
      relation << content_tag('td', risk.assigned_to ? link_to_user(risk.assigned_to) : "-", :class => 'assigned-to')
      relation << content_tag('td', delete_link, :class => 'buttons') if manage_relations

      content_tag('tr', relation, :id => "risk-relation-#{risk.id}", :class => "risk hascontextmenu #{risk.css_classes}")
    end

    content_tag('table', relations.join.html_safe, :class => 'list risks odd-even')
  end

  def risk_details_to_strings(details, no_html=false, options={})
    # The plugin Redmine Checklists patch the method IssuesHelper::details_to_strings and suppose
    # that it's only used for issues. Thus, if the unpatched version exists, we'll use it instead.
    if respond_to?('details_to_strings_without_checklists')
      return details_to_strings_without_checklists(details, no_html, options)
    end

    details_to_strings(details, no_html, options)
  end

  def column_value_with_risks(column, item, value)
    if (item.is_a?(Risk)) 
      case column.name
      when :id, :subject
        link_to value, risk_path(item)
      when :probability
        format_risk_probability(value)
      when :impact
        format_risk_impact(value)
      when :status
        format_risk_status(value)
      when :strategy
        format_risk_strategy(value)
      when :treatments
        item.treatments? ? content_tag('div', textilizable(item, :treatments), :class => "wiki") : ''
      when :lessons
        item.lessons? ? content_tag('div', textilizable(item, :lessons), :class => "wiki") : ''
      else
        column_value_without_risks(column, item, value)
      end
    else
      column_value_without_risks(column, item, value)
    end
  end

  alias_method :column_value_without_risks, :column_value
  alias_method :column_value, :column_value_with_risks
end
