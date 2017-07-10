class CreateProductCategoryDescriptions < ActiveRecord::Migration[5.1]
  def change
    create_table :product_category_descriptions do |t|
      t.references :product_category
      t.string :description, required: true

      t.timestamps
    end
  end
end
