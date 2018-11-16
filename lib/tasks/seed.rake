namespace :risks do

  desc 'Seeding initial risk category values'
  task :seed => :environment do
    RiskCategory.create(:name => I18n.t(:default_risk_category_internal), :position => 1)
    RiskCategory.create(:name => I18n.t(:default_risk_category_external), :position => 2)
    RiskCategory.create(:name => I18n.t(:default_risk_category_technical), :position => 3)
    RiskCategory.create(:name => I18n.t(:default_risk_category_unforeseeable), :position => 4)
  end

end
