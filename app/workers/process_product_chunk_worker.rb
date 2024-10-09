class ProcessProductChunkWorker
  include Sidekiq::Worker
    # sidekiq_options queue: :xml_product

  def perform(url_options, current_store_id, current_currency, product_ids, file_name, channel, doc,  batch_size, batch_index, last_xml_product_id)
     product_ids.each do |product_id|
      if product_id == last_xml_product_id
        last_xml_product = Spree::XmlProduct.find_by(product_id: last_xml_product_id)
        last_xml_product.update(status: "queue")
      end
      SingleProductFeedWorker.perform_async(url_options, current_store_id, current_currency, product_id, file_name, channel,doc,  batch_size, batch_index, product_ids.last, last_xml_product_id)
    end
    GC.start(full_mark: true, immediate_sweep: true)
  end
end
