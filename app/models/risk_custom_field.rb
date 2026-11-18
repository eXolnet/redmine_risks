class RiskCustomField < CustomField
  def type_name
    :label_risk_plural
  end

  def visible_by?(project, user=User.current)
    super || roles.intersect?(user.roles_for_project(project))
  end

  def validate_custom_field
    super
    errors.add(:base, l(:label_role_plural) + ' ' + l('activerecord.errors.messages.blank')) unless visible? || roles.present?
  end
end
