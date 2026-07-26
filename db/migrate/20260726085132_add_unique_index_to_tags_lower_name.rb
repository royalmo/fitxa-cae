class AddUniqueIndexToTagsLowerName < ActiveRecord::Migration[8.1]
  def change
    add_index :tags, "LOWER(name)", unique: true, name: "index_tags_on_lower_name"
  end
end
