class SingleProductFeedWorker
  include Sidekiq::Worker
  # sidekiq_options queue: :xml_product

 def perform(url_options, current_store_id, current_currency, product_id, file_name, channel_string, doc_string, batch_size, batch_index, last_product_id, last_xml_product_id)
  last_xml_product = Spree::XmlProduct.find_by(product_id: last_xml_product_id)
  current_store = Spree::Store.find current_store_id
  product = Spree::Product.find_by(id: product_id)

  begin
    unless product.is_in_hide_from_nav_taxon?
      if product.feed_active?
        if product.variants_and_option_values(current_currency).any?
          product.variants.each do |variant|
            if variant.show_in_product_feed?
              item = Renderer::Products.create_node("item")
              Renderer::Products.complex_product(url_options, current_store, current_currency, item, product, variant, last_xml_product)
              file = File.open(Rails.root.join('tmp', file_name), 'a+')
              if file.include?('</channel>')
                data = "\n</channel>\n</rss>"
                file.to_s.gsub(data, "")
                file.write(item.to_s)
                file.write(data)
              else
                file.write(item.to_s)
              end
            end
          end
        else
          item = Renderer::Products.create_node("item")
          Renderer::Products.basic_product(url_options, current_store, current_currency, item, product, last_xml_product)
          file = File.open(Rails.root.join('tmp', file_name), 'a+') # Use 'w' to open for writing
          file.write(item.to_s)
        end
      end
    end
  ensure
    # Ensure the last condition is always checked, even if the product is skipped or an exception occurs
    if batch_size == (batch_index + 1) && last_xml_product_id == product_id
      last_xml_product.update(status: "processed")
      append_rss_end_tag(file_name, batch_size, batch_index, last_product_id, last_xml_product)
    end
    GC.start(full_mark: true, immediate_sweep: true)
  end
end


  private

  def append_rss_end_tag(file_name, batch_size, batch_index, last_product_id, last_xml_product)
    sleep(10)
    if last_product_id == last_xml_product.product_id && last_xml_product.status == "processed"
      file = File.open(Rails.root.join('tmp', file_name), 'a+')
      file.seek(0, IO::SEEK_END)
      data =  "\n</channel>\n</rss>"
      file.write(data)
      file.close
      last_xml_product.update(status: nil)
    end
  end
end
