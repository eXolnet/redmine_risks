migration_class = ActiveRecord::VERSION::MAJOR >= 7 ? ActiveRecord::Migration[7.0] : ActiveRecord::Migration[4.2]

class ChangeDefaultRiskStatus < migration_class
  def change
    # Both Risk and its :status machine should have the same default value to avoid inconsistencies
    change_column_default(:risks, :status, from: "opened", to: "open")
  end
end
