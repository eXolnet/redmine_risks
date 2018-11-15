class RiskCategory < Enumeration
  has_many :risks, :foreign_key => 'category_id'

  OptionName = :enumeration_risk_categories

  def option_name
    OptionName
  end

  def objects_count
    risks.count
  end

  def transfer_relations(to)
    risks.update_all(:category_id => to.id)
  end

  def self.default
    d = super
    d = first if d.nil?
    d
  end
end
