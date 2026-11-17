class RiskContextMenusController < ApplicationController
  helper :context_menus
  helper :risks

  def index
    @risks = Risk.where(:id => params[:ids]).to_a

    unless @risks.present?
      render_404
      return
    end

    @risk_ids = @risks.map(&:id).sort
    @risk = @risks.first if @risks.size == 1

    @projects = @risks.collect(&:project).compact.uniq
    @assignables = @risks.map(&:assignable_users).reduce(:&)
    @safe_attributes = @risks.map(&:safe_attribute_names).reduce(:&)

    edit_allowed = @risks.all? {|t| t.editable?(User.current)}
    @can = {:edit => edit_allowed, :delete => edit_allowed}
    @back = back_url

    render :template => 'context_menus/risks', :layout => false
  end
end
