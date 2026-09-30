class RiskIssuesController < ApplicationController
  before_action :find_risk
  before_action :ensure_authorized

  helper :risks
  include RisksHelper

  def create_by_risk
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

  def destroy_by_risk
    @issue = @risk.issues.visible.find_by_id(params[:issue_id])

    if @issue
      @risk.init_journal(User.current)
      @risk.issues.delete(@issue)
    end
  end

  def create_by_issue
    risk_id = params[:risk_id].to_s.sub(/^#/,'')
    @risk = Risk.find_by_id(risk_id)
    @issue = Issue.find_by_id(params[:issue_id].to_i)

    if @risk && (!@risk.visible? || @risk.issues.include?(@issue))
      @risk = nil
    end

    if @risk
      @risk.init_journal(User.current)
      @risk.issues << @issue
    end
  end

  def destroy_by_issue
    @risk = Risk.find_by_id(params[:risk_id])
    @issue = Issue.find_by_id(params[:issue_id].to_i)

    if @risk
      @risk.init_journal(User.current)
      @risk.issues.delete(@issue)
    end
  end

  private

  def ensure_authorized
    unless @risk.nil?
      raise Unauthorized unless User.current.allowed_to?(:manage_risk_relations, @risk.project)
    end
    unless @issue.nil?
      raise Unauthorized unless User.current.allowed_to?(:manage_risk_relations, @issue.project)  
    end
  end
end
