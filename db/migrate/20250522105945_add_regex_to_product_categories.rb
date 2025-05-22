class AddRegexToProductCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :product_categories, :regex, :string
  end
end
