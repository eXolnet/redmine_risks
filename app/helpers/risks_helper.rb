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

  def render_risk_relations(risk)
    manage_relations = User.current.allowed_to?(:manage_risk_relations, risk.project)

    relations = risk.issues.visible.collect do |issue|
      delete_link = link_to(l(:label_relation_delete),
                            {:controller => 'risk_issues', :action => 'destroy', :risk_id => @risk, :issue_id => issue},
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

  def column_value_with_risks(column, item, value)
    if item.is_a?(Risk)
      if [:id, :subject].include? column.name
        return link_to_risk item, :text => value
      end
    end

    column_value_without_risks(column, item, value)
  end

  alias_method_chain :column_value, :risks
end
