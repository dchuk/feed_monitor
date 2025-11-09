# frozen_string_literal: true

class AddNotNullConstraintsToItems < ActiveRecord::Migration[8.0]
  def up
    # First, clean up any existing invalid data
    # For guid: use content_fingerprint or generate a UUID as fallback
    execute <<~SQL
      UPDATE sourcemon_items
      SET guid = COALESCE(content_fingerprint, gen_random_uuid()::text)
      WHERE guid IS NULL
    SQL

    # For url: use canonical_url or a placeholder as fallback
    execute <<~SQL
      UPDATE sourcemon_items
      SET url = COALESCE(canonical_url, 'https://unknown.example.com')
      WHERE url IS NULL
    SQL

    # Now add the NOT NULL constraints
    change_column_null :sourcemon_items, :guid, false
    change_column_null :sourcemon_items, :url, false
  end

  def down
    # Allow NULL values again
    change_column_null :sourcemon_items, :guid, true
    change_column_null :sourcemon_items, :url, true
  end
end
