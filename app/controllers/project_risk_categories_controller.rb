class ProjectRiskCategoriesController < ApplicationController
  menu_item :settings

  before_action :find_project_by_project_id
  before_action :authorize
  before_action :find_project_specific_category, :only => :destroy

  # Adds a category specific to the project
  def create
    category = @project.risk_categories.build(:name => params.dig(:risk_category, :name), :active => true)
    if category.save
      flash[:notice] = l(:notice_successful_create)
    else
      flash[:error] = category.errors.full_messages.join(', ')
    end

    redirect_to settings_project_path(@project, :tab => 'risks')
  end

  # Enables or disables the system categories in the project, and enables,
  # disables or renames the categories specific to the project
  def update
    if @project.update_or_create_risk_categories(update_params)
      flash[:notice] = l(:notice_successful_update)
    else
      invalid = @project.invalid_risk_category
      flash[:error] = "#{invalid.name_was.presence || invalid.name}: #{invalid.errors.full_messages.join(', ')}"
    end

    redirect_to settings_project_path(@project, :tab => 'risks')
  end

  # Resets the overrides of the system categories (the categories specific
  # to the project are kept)
  def reset
    @project.risk_categories.where.not(:parent_id => nil).each do |category|
      category.destroy(category.parent)
    end
    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'risks')
  end

  # Deletes a category specific to the project. Its risks must be reassigned
  # to another category of the project, or left without category.
  def destroy
    if @category.in_use?
      unless params.key?(:reassign_to_id)
        @categories = @project.risk_categories_available(true).to_a - [@category]
        render :destroy
        return
      end

      if params[:reassign_to_id].present?
        reassign_to = @project.risk_categories_available(true).where.not(:id => @category.id).
          find_by_id(params[:reassign_to_id].to_i)
        return render_404 unless reassign_to

        @category.transfer_relations(reassign_to)
      else
        @category.objects.update_all(:category_id => nil)
      end
    end

    @category.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to settings_project_path(@project, :tab => 'risks')
  end

  private

  def find_project_specific_category
    @category = @project.risk_categories.where(:parent_id => nil).find_by_id(params[:id])
    render_404 unless @category
  end

  def update_params
    params.
      permit(:enumerations => [:parent_id, :active, :name, {:custom_field_values => {}}]).
      require(:enumerations)
  end
end
