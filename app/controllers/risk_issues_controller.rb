class RiskIssuesController < ApplicationController
  before_action :find_risk
  before_action :ensure_authorized

  accept_api_auth :create, :destroy

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

    respond_to do |format|
      format.js
      format.api {
        if @issue
          render_api_ok
        else
          render_api_errors(l(:error_risk_issue_not_linkable))
        end
      }
    end
  end

  def destroy
    @issue = @risk.issues.visible.find_by_id(params[:issue_id])

    if @issue
      @risk.init_journal(User.current)
      @risk.issues.delete(@issue)
    end

    respond_to do |format|
      format.js
      format.api {
        if @issue
          render_api_ok
        else
          render_404
        end
      }
    end
  end

  private

  def ensure_authorized
    raise Unauthorized unless User.current.allowed_to?(:manage_risk_relations, @risk.project)
  end
end
