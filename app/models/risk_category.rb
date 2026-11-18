class RiskCategory < Enumeration
  has_many :risks, :foreign_key => 'category_id'

  OptionName = :enumeration_risk_categories

  def option_name
    OptionName
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
end
