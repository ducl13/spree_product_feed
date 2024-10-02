class SingleProductFeedWorker
  include Sidekiq::Worker

  def perform(url_options, current_store_id, current_currency, product_id, file_name)
    current_store = Spree::Store.find current_store_id

    doc = Renderer::Products.create_doc_xml("rss", { :attributes => { "xmlns:g" => "http://base.google.com/ns/1.0", "version" => "2.0" } })
    doc.root << (channel = Renderer::Products.create_node("channel"))

    channel << Renderer::Products.create_node("title", current_store.name)
    channel << Renderer::Products.create_node("link", current_store.url)
    channel << Renderer::Products.create_node("description", "Find out about new products first! Always be in the know when new products become available")

    if defined?(current_store.default_locale) && !current_store.default_locale.nil?
      channel << Renderer::Products.create_node("language", current_store.default_locale.downcase)
    else
      channel << Renderer::Products.create_node("language", "en-us")
    end

    file = File.new("./tmp/#{file_name}", 'w')
    file.sync = true
    product = Spree::Product.find_by(id: product_id)
    if product.is_in_hide_from_nav_taxon?
      return
    elsif product.feed_active?
      if product.variants_and_option_values(current_currency).any?
        product.variants.each do |variant|
          if variant.show_in_product_feed?
            channel << (item = Renderer::Products.create_node("item"))
            Renderer::Products.complex_product(url_options, current_store, current_currency, item, product, variant)
          end
        end
      else
        channel << (item = Renderer::Products.create_node("item"))
        Renderer::Products.basic_product(url_options, current_store, current_currency, item, product)
      end
    file.write(doc.to_s)
    file.close
    end    
    GC.start(full_mark: true, immediate_sweep: true)
  end
end
