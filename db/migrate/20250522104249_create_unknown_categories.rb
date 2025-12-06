class CreateUnknownCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :unknown_categories do |t|
      t.string :description
      t.decimal :price, precision: 10, scale: 2

      t.timestamps
    end
  end
end
