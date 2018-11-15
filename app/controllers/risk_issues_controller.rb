class RiskIssuesController < ApplicationController
  before_action :find_risk
  before_action :ensure_authorized

  helper :risks
  include RisksHelper

  def create
    issue_id = params[:issue_id].to_s.sub(/^#/,'')
    @issue = @risk.find_referenced_issue_by_id(issue_id)

    if @issue && (!@issue.visible? || @risk.issues.include?(@issue))
      @issue = nil
    end

    if @issue
      @risk.init_journal(User.current)
      @risk.issues << @issue
    end
  end

  def destroy
    @issue = Issue.visible.find_by_id(params[:issue_id])

    if @issue
      @risk.init_journal(User.current)
      @risk.issues.delete(@issue)
    end
  end

  private

  def ensure_authorized
    raise Unauthorized unless User.current.allowed_to?(:manage_risk_relations, @risk.project)
  end
end
