class RiskDashboardsController < ApplicationController
  menu_item :risks

  before_action :find_project_by_project_id, :authorize

  helper :risks
  helper :risk_dashboards

  TOP_RISKS_LIMIT = 5

  def show
    scope = risk_scope
    open_scope = scope.open

    @status_counts = Risk::RISK_STATUS.index_with {|status| 0 }.merge(scope.group(:status).count)
    @open_count = open_scope.count

    @matrix = open_scope.
      where.not(:probability => nil).
      where.not(:impact => nil).
      group(:probability, :impact).
      count
    @unrated_count = @open_count - matrix_levels.sum {|p| matrix_levels.sum {|i| @matrix[[p, i]].to_i } }

    @top_risks = open_scope.
      where.not(:probability => nil).
      where.not(:impact => nil).
      preload(:category, :assigned_to).
      order(Arel.sql("#{Risk.table_name}.impact * #{Risk.table_name}.probability DESC"), :id).
      limit(TOP_RISKS_LIMIT).
      to_a

    category_counts = open_scope.group(:category_id).count
    categories = RiskCategory.where(:id => category_counts.keys.compact).sort
    @category_counts = categories.map {|category| [category, category_counts.delete(category.id)] }
    # Risks without category, or with a category that no longer exists
    uncategorized_count = category_counts.values.sum
    @category_counts << [nil, uncategorized_count] if uncategorized_count > 0

    strategy_counts = open_scope.group(:strategy).count
    @strategy_counts = (Risk::RISK_STRATEGY + [nil]).
      select {|strategy| strategy_counts[strategy] }.
      map {|strategy| [strategy, strategy_counts[strategy]] }
  end

  private

  # Risks visible in the project risk list (subprojects included according to
  # the Redmine settings), without any filter.
  def risk_scope
    query = RiskQuery.new(:name => '_', :project => @project)
    query.filters = {}
    query.base_scope
  end

  def matrix_levels
    helpers.risk_matrix_levels(Risk::RISK_PROBABILITY)
  end
end
