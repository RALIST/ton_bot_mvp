class CreateInitialSchema < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'vector' unless extension_enabled?('vector')

    create_table :raw_documents do |t|
      t.string :url, null: false
      t.string :title
      t.text :content
      t.text :html_content
      t.string :section
      t.jsonb :metadata, default: {}
      t.boolean :processed, default: false
      t.timestamps

      t.index :url, unique: true
      t.index :processed
      t.index :created_at
    end

    create_table :embeddings do |t|
      t.references :document, null: false, foreign_key: { to_table: :raw_documents }
      t.text :content, null: false
      t.vector :embedding, limit: 1536
      t.string :url
      t.string :section
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index :created_at
      t.index :embedding, using: :ivfflat, opclass: :vector_cosine_ops
    end
  end
end
