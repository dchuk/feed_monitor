# frozen_string_literal: true

class CreateSourceMonitorItemContents < ActiveRecord::Migration[8.0]
  def up
    create_table :sourcemon_item_contents do |t|
      t.references :item, null: false, foreign_key: { to_table: :sourcemon_items }, index: { unique: true }
      t.text :scraped_html
      t.text :scraped_content

      t.timestamps(null: false)
    end

    execute <<~SQL
      INSERT INTO sourcemon_item_contents (item_id, scraped_html, scraped_content, created_at, updated_at)
      SELECT id, scraped_html, scraped_content, COALESCE(updated_at, CURRENT_TIMESTAMP), COALESCE(updated_at, CURRENT_TIMESTAMP)
      FROM sourcemon_items
      WHERE scraped_html IS NOT NULL OR scraped_content IS NOT NULL
    SQL

    remove_column :sourcemon_items, :scraped_html, :text
    remove_column :sourcemon_items, :scraped_content, :text
  end

  def down
    add_column :sourcemon_items, :scraped_html, :text
    add_column :sourcemon_items, :scraped_content, :text

    execute <<~SQL
      UPDATE sourcemon_items items
      SET scraped_html = contents.scraped_html,
          scraped_content = contents.scraped_content
      FROM sourcemon_item_contents contents
      WHERE contents.item_id = items.id
    SQL

    drop_table :sourcemon_item_contents
  end
end
