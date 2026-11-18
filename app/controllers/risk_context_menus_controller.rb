class RiskContextMenusController < ApplicationController
  helper :context_menus
  helper :risks

  before_action :find_risks

  include RisksHelper

  def index
    @risk_ids = @risks.map(&:id).sort
    @risk = @risks.first if @risks.size == 1

    @projects = @risks.collect(&:project).compact.uniq
    @assignables = @risks.map(&:assignable_users).reduce(:&)
    @safe_attributes = @risks.map(&:safe_attribute_names).reduce(:&)

    @can = {
      :edit => @risks.all? {|t| t.editable?(User.current)},
      :delete => @risks.all? {|t| t.deletable?(User.current)}
    }
    @back = back_url

    render :template => 'context_menus/risks', :layout => false
  end
end
