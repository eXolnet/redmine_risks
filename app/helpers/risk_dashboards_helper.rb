module RiskDashboardsHelper
  # Returns the stored values (0 to 100) of the given risk levels
  def risk_matrix_levels(levels)
    increment = 100 / (levels.count - 1)

    (0...levels.count).map {|index| index * increment }
  end

  # Returns the CSS class of a magnitude level index (eg. "magnitude-high")
  def risk_magnitude_css(level)
    return 'magnitude-none' if level.nil?

    "magnitude-#{Risk::RISK_MAGNITUDE[level]}"
  end

  # Returns the path to the risk list of +project+ filtered with +filters+,
  # a hash of field => values using the "is" operator
  def risks_filtered_path(project, filters)
    project_risks_path(project,
                       :set_filter => 1,
                       :f => filters.keys.map(&:to_s) + [''],
                       :op => filters.keys.index_with {|field| '=' },
                       :v => filters.transform_values {|values| Array(values).map(&:to_s) })
  end

  # Renders a link to the risk list filtered with +filters+ (plus open risks)
  def link_to_open_risks(project, label, filters = {}, options = {})
    link_to label.to_s, risks_filtered_path(project, {:status => 'open'}.merge(filters)), options
  end

  # Returns the width percentage of +count+ relatively to +total+
  def risk_dashboard_ratio(count, total)
    return 0 if total.to_i.zero?

    (count * 100.0 / total).round
  end
end
