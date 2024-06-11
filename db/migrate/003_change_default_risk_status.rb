migration_class = ActiveRecord::VERSION::MAJOR >= 5 ? ActiveRecord::Migration[4.2] : ActiveRecord::Migration

class ChangeDefaultRiskStatus < migration_class
  def change
    # Both Risk and its :status machine should have the same default value to avoid inconsistencies
    change_column_default(:risks, :status, from: "opened", to: "open")
  end
end
