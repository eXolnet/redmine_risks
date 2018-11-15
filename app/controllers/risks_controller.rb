class RisksController < ApplicationController
  default_search_scope :risks
  menu_item :risks

  before_action :find_pull, :only => [:show, :edit, :update, :destroy, :quoted]
  before_action :find_optional_project, :only => [:index, :new, :create]
  before_action :build_new_pull_from_params, :only => [:new, :create]

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :projects
  helper :custom_fields
  helper :issues
  helper :queries
  include QueriesHelper
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
end
