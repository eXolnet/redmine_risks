class IssueRisksController < ApplicationController
  before_action :find_issue
  before_action :find_linkable_risk

  def create
    if @risk && @risk.issues.include?(@issue)
      @risk = nil
    end

    if @risk
      @risk.init_journal(User.current)
      @risk.issues << @issue
    end

    respond_to do |format|
      format.js
    end
  end

  def destroy
    if @risk && !@risk.issues.include?(@issue)
      @risk = nil
    end

    if @risk
      @risk.init_journal(User.current)
      @risk.issues.delete(@issue)
    end

    respond_to do |format|
      format.js
    end
  end

  private

  def find_issue
    @issue = Issue.visible.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Finds the risk to link or unlink. @risk is left to nil when the risk does
  # not exist, is not visible, or when the user cannot manage its relations.
  def find_linkable_risk
    risk = Risk.find_by_id(params[:risk_id].to_s.strip.sub(/^#/, ''))

    if risk && risk.visible? && User.current.allowed_to?(:manage_risk_relations, risk.project)
      @risk = risk
    end
  end
end
