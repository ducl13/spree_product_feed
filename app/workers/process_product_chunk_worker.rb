class ProcessProductChunkWorker
  include Sidekiq::Worker

  def perform(url_options, current_store_id, current_currency, product_ids, file_name)
    product_ids.each do |product_id|
      SingleProductFeedWorker.perform_async(url_options, current_store_id, current_currency, product_id, file_name)
    end

    GC.start(full_mark: true, immediate_sweep: true)
  end
end
