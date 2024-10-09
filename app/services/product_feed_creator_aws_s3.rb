class ProductFeedCreatorAwsS3 < ApplicationService
  FEED_FILE_NAME = "product-feed"

  def initialize(url_options, current_store, current_currency, products, index)
    @url_options = url_options
    @current_store = current_store
    @current_currency = current_currency
    @products = products
    @file_name = "#{FEED_FILE_NAME}-#{index}.xml"
  end

  def call
    generate_feed_file
    upload_to_s3
    GC.start(full_mark: true, immediate_sweep: true) # Force GC after execution
  end

  def generate_feed_file
    File.open("./tmp/#{@file_name}", 'w') do |file|
      file.sync = true
      # Write XML header
      file.write(Renderer::Products.create_xml_header(@url_options, @current_store))

      # Process products in batches
      @products.each_slice(100) do |batch_products|
        xml_part = Renderer::Products.xml_batch(@url_options, @current_store, @current_currency, batch_products)
        file.write(xml_part)

        # Trigger garbage collection after each batch
        GC.start(full_mark: true, immediate_sweep: true)
      end

      # Write XML footer
      file.write(Renderer::Products.create_xml_footer)
    end
  end

  def upload_to_s3
    bucket_name = "#{ENV['S3_PRODUCT_FEED_BUCKET']}"
    object_key = @file_name

    s3_client = Aws::S3::Client.new(
      region: ENV['S3_PRODUCT_FEED_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_KEY']
    )

    File.open("./tmp/#{@file_name}", 'rb') do |file|
      if object_uploaded?(s3_client, bucket_name, object_key, file)
        puts "Object '#{object_key}' uploaded to bucket '#{bucket_name}'."
      else
        puts "Object '#{object_key}' not uploaded to bucket '#{bucket_name}'."
      end
    end
  end

  def object_uploaded?(s3_client, bucket_name, object_key, file)
    response = s3_client.put_object(
      bucket: bucket_name,
      key: object_key,
      body: file
    )
    response.etag ? true : false
  rescue StandardError => e
    puts "Error uploading object: #{e.message}"
    false
  end
end