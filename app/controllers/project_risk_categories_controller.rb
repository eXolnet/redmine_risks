class ProjectRiskCategoriesController < ApplicationController
  menu_item :settings

  before_action :find_project_by_project_id
  before_action :authorize

  def update
    if @project.update_or_create_risk_categories(update_params)
      flash[:notice] = l(:notice_successful_update)
    end

    redirect_to settings_project_path(@project, :tab => 'risks')
  end

  # Resets the project categories to the system categories
  def destroy
    @project.risk_categories.each do |category|
      category.destroy(category.parent)
    end
    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'risks')
  end

  private

  def update_params
    params.
      permit(:enumerations => [:parent_id, :active, {:custom_field_values => {}}]).
      require(:enumerations)
  end
end
