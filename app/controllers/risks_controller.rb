class RisksController < ApplicationController
  default_search_scope :risks
  menu_item :risks

  before_action :find_risk, :only => [:show, :edit, :update, :quoted]
  before_action :find_risks, :only => [:bulk_update, :destroy]
  before_action :find_optional_project, :only => [:index, :new, :create]
  before_action :build_new_risk_from_params, :only => [:new, :create]

  accept_atom_auth :index, :show
  accept_api_auth :index, :show, :create, :update, :destroy

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :projects
  helper :custom_fields
  helper :queries
  include RisksHelper

  def index
    retrieve_query(RiskQuery, !request.format.csv?)

    if @query.valid?
      respond_to do |format|
        format.html {
          @risk_count = @query.risk_count
          @risk_pages = Paginator.new @risk_count, per_page_option, params['page']
          @risks = @query.risks(:offset => @risk_pages.offset, :limit => @risk_pages.per_page)
          render :layout => !request.xhr?
        }
        format.api {
          @offset, @limit = api_offset_and_limit
          @risk_count = @query.risk_count
          @risks = @query.risks(:offset => @offset, :limit => @limit, :include => [:author, :assigned_to])
        }
        format.atom {
          risks = @query.risks(:limit => Setting.feeds_limit.to_i)
          render_feed(risks, :title => "#{@project || Setting.app_title}: #{l(:label_risks)}")
        }
        format.csv {
          risks = @query.risks(:limit => Setting.issues_export_limit.to_i)
          send_data(query_to_csv(risks, @query, params[:csv]),
                    :type => 'text/csv; header=present', :filename => "#{filename_for_export(@query, 'risks')}.csv")
        }
        format.pdf {
          @risks = @query.risks(:limit => Setting.issues_export_limit.to_i)
          send_file_headers! :type => 'application/pdf', :filename => "#{filename_for_export(@query, 'risks')}.pdf"
        }
      end
    else
      respond_to do |format|
        format.html { render :layout => !request.xhr? }
        format.any(:atom, :csv, :pdf) { head :unprocessable_content }
        format.api  { render_validation_errors(@query) }
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
        format.api  { render_validation_errors(@risk) }
      end
    end

    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_risk_successful_create, :id => view_context.link_to("##{@risk.id}", risk_path(@risk), :title => @risk.subject))

        if params[:continue]
          redirect_to new_project_risk_path(@project, { :back_url => params[:back_url].presence })
        else
          redirect_back_or_default risk_path(@risk)
        end
      }
      format.api {
        render :action => 'show', :status => :created, :location => risk_url(@risk)
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
      format.api
      format.atom {
        render :layout => false, :content_type => 'application/atom+xml'
      }
      format.pdf {
        send_file_headers! :type => 'application/pdf', :filename => "#{@project.identifier}-risk-#{@risk.id}.pdf"
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
      flash[:notice] = l(:notice_risk_successful_update) unless api_request? || @risk.current_journal.new_record?

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
    raise Unauthorized unless @risks.all?(&:deletable?)

    @risks.each do |risk|
      begin
        risk.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
        # nothing to do, issue was already deleted (eg. by a parent)
      end
    end

    flash[:notice] = l(:notice_risk_successful_delete) unless api_request?

    respond_to do |format|
      format.html { redirect_back_or_default(@project ? project_risks_path(@project) : home_path) }
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
    @risks.sort!

    raise ::Unauthorized unless @risks.all?(&:attributes_editable?)

    attributes = parse_params_for_bulk_update(params[:risk])
    risks_unsaved = []
    risks_saved = []

    @risks.each do |risk_original|
      risk_original.reload

      risk = risk_original

      risk.init_journal(User.current, params[:notes])
      risk.safe_attributes = attributes

      if risk.save
        risks_saved << risk
      else
        risks_unsaved << risk_original
      end
    end

    if risks_unsaved.empty?
      flash[:notice] = l(:notice_risk_successful_update) unless risks_saved.empty?
    end

    redirect_back_or_default(@project ? project_risks_path(@project) : home_path)
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
    risk_attributes.transform_values! { |value| value.present? ? value : nil }

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
