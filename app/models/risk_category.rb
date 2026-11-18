class RiskCategory < Enumeration
  has_many :risks, :foreign_key => 'category_id'

  OptionName = :enumeration_risk_categories

  validate :validate_project_specific_name

  def option_name
    OptionName
  end

  # Is this category specific to a project (not an override of a system category)?
  def project_specific?
    project_id.present? && parent_id.nil?
  end

  # SQL expression sorting the categories specific to a project after the
  # system categories (and their overrides)
  def self.project_specific_order_sql
    t = table_name
    "CASE WHEN #{t}.project_id IS NOT NULL AND #{t}.parent_id IS NULL THEN 1 ELSE 0 END"
  end

  # The categories specific to a project come after the system categories
  def <=>(other)
    return super unless other.is_a?(RiskCategory)

    [project_specific? ? 1 : 0, position.to_i, id.to_i] <=> [other.project_specific? ? 1 : 0, other.position.to_i, other.id.to_i]
  end

  # Risks using this category or one of its project overrides
  def objects
    Risk.where(:category_id => self_and_descendants(1).map(&:id))
  end

  def objects_count
    objects.count
  end

  def transfer_relations(to)
    objects.update_all(:category_id => to.id)
  end

  # Returns the default category, or its override in the given project
  def self.default(project = nil)
    d = super()
    d = shared.first if d.nil?
    return d if d.nil? || project.nil?

    available = project.risk_categories_available.to_a
    return d if available.include?(d)

    available.detect {|c| c.parent_id == d.id }
  end

  # Returns the categories that can be selected for a risk of the given project
  def self.available_categories(project = nil)
    if project.nil?
      shared.active
    else
      project.risk_categories_available
    end
  end

  private

  # A project specific category can't take the name of a system category,
  # which would be ambiguous with the system category or its override
  def validate_project_specific_name
    return unless project_specific? && name.present?

    if RiskCategory.shared.where.not(:id => id).named(name).exists?
      errors.add :name, :taken
    end
  end
end
