class CreateEmailMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :email_metrics do |t|
      t.references :user, null: false, foreign_key: true
      t.string :email_type
      t.string :status
      t.string :subject
      t.datetime :sent_at
      
      t.timestamps
    end
  end
end 