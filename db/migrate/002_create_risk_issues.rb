class CreateRiskIssues < ActiveRecord::Migration
  def change
    create_table :risk_issues do |t|
      t.integer  :risk_id,      :null => false
      t.integer  :issue_id,     :null => false
    end

    add_index :risk_issues, [:risk_id, :issue_id], :unique => true, :name => :risk_issues_ids
  end
end
