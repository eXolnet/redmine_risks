migration_class = ActiveRecord::VERSION::MAJOR >= 7 ? ActiveRecord::Migration[7.0] : ActiveRecord::Migration[4.2]

class CreateRisks < migration_class
  def change
    create_table :risks do |t|
      t.integer  :project_id,            :null => false
      t.string   :subject,               :null => false
      t.text     :description
      t.text     :treatments
      t.text     :lessons
      t.string   :status,                :null => false, :default => "opened"
      t.integer  :category_id
      t.integer  :probability
      t.integer  :impact
      t.string   :strategy
      t.integer  :author_id,             :null => false
      t.integer  :assigned_to_id
      t.datetime :created_on,            :null => false
      t.datetime :updated_on,            :null => false
      t.datetime :closed_on
    end
  end
end
