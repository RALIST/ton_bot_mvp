class CreateFailedScrapes < ActiveRecord::Migration[7.0]
  def change
    create_table :failed_scrapes do |t|
      t.string :url, null: false
      t.string :source, null: false
      t.text :error
      t.integer :retry_count, default: 0
      t.datetime :last_retry_at
      t.timestamps

      t.index [:url, :source], unique: true
      t.index :retry_count
      t.index :last_retry_at
      t.index :source
    end
  end
end
