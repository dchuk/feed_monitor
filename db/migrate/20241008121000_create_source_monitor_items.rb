# frozen_string_literal: true

class CreateSourceMonitorItems < ActiveRecord::Migration[8.0]
  def change
    create_table :sourcemon_items do |t|
      t.references :source, null: false, foreign_key: { to_table: :sourcemon_sources }
      t.string :guid
      t.string :content_fingerprint
      t.string :title
      t.string :url
      t.string :canonical_url
      t.string :author
      t.jsonb :authors, null: false, default: []
      t.text :summary
      t.text :content
      t.text :scraped_html
      t.text :scraped_content
      t.datetime :scraped_at
      t.string :scrape_status
      t.datetime :published_at
      t.datetime :updated_at_source
      t.jsonb :categories, null: false, default: []
      t.jsonb :tags, null: false, default: []
      t.jsonb :keywords, null: false, default: []
      t.jsonb :enclosures, null: false, default: []
      t.string :media_thumbnail_url
      t.jsonb :media_content, null: false, default: []
      t.string :language
      t.string :copyright
      t.string :comments_url
      t.integer :comments_count, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :sourcemon_items, :guid
    add_index :sourcemon_items, :content_fingerprint
    add_index :sourcemon_items, :url
    add_index :sourcemon_items, :scrape_status
    add_index :sourcemon_items, :published_at
    add_index :sourcemon_items, [ :source_id, :guid ], unique: true
    add_index :sourcemon_items, [ :source_id, :content_fingerprint ], unique: true
  end
end
