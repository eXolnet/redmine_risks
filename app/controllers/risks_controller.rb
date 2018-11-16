class RisksController < ApplicationController
  default_search_scope :risks
  menu_item :risks

  before_action :find_risk, :only => [:show, :edit, :update, :destroy, :quoted]
  before_action :find_optional_project, :only => [:index, :new, :create]
  before_action :build_new_risk_from_params, :only => [:new, :create]

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :projects
  helper :custom_fields
  include RisksHelper

  def index
    retrieve_query(RiskQuery)

    if @query.valid?
      respond_to do |format|
        format.html {
          @risk_count = @query.risk_count
          @risk_pages = Paginator.new @risk_count, per_page_option, params['page']
          @risks = @query.risks(:offset => @risk_pages.offset, :limit => @risk_pages.per_page)
          render :layout => !request.xhr?
        }
      end
    else
      respond_to do |format|
        format.html { render :layout => !request.xhr? }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def new
    respond_to do |format|
      format.html { render :action => 'new', :layout => !request.xhr? }
    end
  end

  def create
    raise Unauthorized unless User.current.allowed_to?(:add_risks, @risk.project)

    unless @risk.save
      return respond_to do |format|
        format.html { render :action => 'new' }
      end
    end

    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_risk_successful_create, :id => view_context.link_to("##{@risk.id}", risk_path(@risk), :title => @risk.subject))

        if params[:continue]
          redirect_to _new_project_risk_path(@project, { :back_url => params[:back_url].presence })
        else
          redirect_back_or_default risk_path(@risk)
        end
      }
    end
  end

  def show
    @journals = @risk.visible_journals_with_index

    if User.current.wants_comments_in_reverse_order?
      @journals.reverse!
    end

    respond_to do |format|
      format.html {
        render :template => 'risks/show'
      }
    end
  end

  def edit
    return unless update_risk_from_params

    respond_to do |format|
      format.html { }
    end
  end

  def update
    return unless update_risk_from_params

    saved = false
    begin
      saved = save_risk
    rescue ActiveRecord::StaleObjectError
      @conflict = true

      if params[:last_journal_id]
        @conflict_journals = @risk.journals_after(params[:last_journal_id]).to_a
        @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @risk.project)
      end
    end

    if saved
      flash[:notice] = l(:notice_risk_successful_update) unless @risk.current_journal.new_record?

      respond_to do |format|
        format.html { redirect_back_or_default risk_path(@risk) }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@risk) }
      end
    end
  end

  def destroy
    raise Unauthorized unless @risk.deletable?

    @risk.destroy

    flash[:notice] = l(:notice_risk_successful_delete)

    respond_to do |format|
      format.html { redirect_back_or_default project_risks_path(@project) }
      format.api  { render_api_ok }
    end
  end

  def preview
    @risk        = Risk.find_by_id(params[:id]) unless params[:id].blank?
    @description = params[:risk] && params[:risk][:description]

    if @risk
      raise Unauthorized unless @risk.editable? || @risk.notes_addable?

      if @description && @description.gsub(/(\r?\n|\n\r?)/, "\n") == @risk.description.to_s.gsub(/(\r?\n|\n\r?)/, "\n")
        @description = nil
      end

      @notes   = params[:journal] ? params[:journal][:notes] : nil
      @notes ||= params[:risk] ? params[:risk][:notes] : nil
    end

    render :layout => false
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def quoted
    raise Unauthorized unless @risk.notes_addable?

    user = @risk.author
    text = @risk.description

    # Replaces pre blocks with [...]
    text = text.to_s.strip.gsub(%r{<pre>(.*?)</pre>}m, '[...]')
    @content = "#{ll(Setting.default_language, :text_user_wrote, user)}\n> "
    @content << text.gsub(/(\r?\n|\r\n?)/, "\n> ") + "\n\n"

    render :template => 'journals/new'
  end

  def bulk_update
    #
  end

  private

  def build_new_risk_from_params
    @risk = Risk.new
    @risk.project = @project
    @risk.author ||= User.current

    attrs = (params[:risk] || {}).deep_dup
    attrs.delete_if {|k,v| v.blank?}

    @risk.safe_attributes = attrs
  end

  def build_risk_params_for_update
    risk_attributes = (params[:risk] || {}).deep_dup

    if risk_attributes && params[:conflict_resolution]
      case params[:conflict_resolution]
      when 'overwrite'
        risk_attributes.delete(:lock_version)
      when 'add_notes'
        risk_attributes = risk_attributes.slice(:notes, :private_notes)
      when 'cancel'
        return nil
      end
    end

    risk_attributes
  end

  # Used by #edit and #update to set some common instance variables
  # from the params
  def update_risk_from_params
    raise ::Unauthorized unless @risk.editable?

    risk_attributes = build_risk_params_for_update

    if risk_attributes.nil?
      redirect_to risk_path(@risk)
      return false
    end

    @risk.init_journal(User.current)
    @risk.safe_attributes = risk_attributes

    true
  end

  # Saves @risk from the parameters
  def save_risk
    Risk.transaction do
      call_hook(:controller_risks_edit_before_save, { :params => params, :risk => @risk, :journal => @risk.current_journal})

      raise ActiveRecord::Rollback unless @risk.save

      call_hook(:controller_risks_edit_after_save, { :params => params, :risk => @risk, :journal => @risk.current_journal})

      true
    end
  end
end
