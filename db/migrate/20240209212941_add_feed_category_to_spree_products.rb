class AddProductFeedCategoryToSpreeProducts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_products, :feed_category, :string
  end
end
