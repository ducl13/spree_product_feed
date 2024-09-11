class SingleProductFeedWorker
  include Sidekiq::Worker

  
  def perform(url_options, current_store_id, current_currency, product_id, channel)
    product = Spree::Product.find_by(id: product_id)
    if product.is_in_hide_from_nav_taxon?
      return
    elsif product.feed_active?
      if product.variants_and_option_values(current_currency).any?
        product.variants.each do |variant|
          if variant.show_in_product_feed?
            item = Renderer::Products.create_node("item")
            channel << item.to_s
            Renderer::Products.complex_product(url_options, current_store_id, current_currency, item, product, variant)
          end
        end
      else
        item = Renderer::Products.create_node("item")
        channel << item.to_s
        Renderer::Products.basic_product(url_options, current_store_id, current_currency, item, product)
      end
    end    
    
    GC.start(full_mark: true, immediate_sweep: true)
  end
end
