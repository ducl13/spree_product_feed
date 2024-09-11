class ProcessProductChunkWorker
  include Sidekiq::Worker

  def perform(url_options, current_store_id, current_currency, product_ids,channel)
    product_ids.each do |product_id|
      SingleProductFeedWorker.perform_async(url_options, current_store_id, current_currency, product_id, channel)
    end
    GC.start
  end
end
