class ProductFeedCreatorAwsS3 < ApplicationService
  FEED_FILE_NAME = "product-feed"

  def initialize(url_options, current_store, current_currency, products, index)
    @url_options = url_options
    @current_store = current_store
    @current_currency = current_currency
    @products = products
    @file_name = "#{FEED_FILE_NAME}-#{index}.xml"
  end

  def call()
    generate_feed_file()
    upload_to_s3()
    GC.start(full_mark: true, immediate_sweep: true)
  end

  def generate_feed_file()
    xml = Renderer::Products.xml(@url_options, @current_store, @current_currency, @products, @file_name)
  end

  def object_uploaded?(s3_client, bucket_name, object_key, file)
    response = s3_client.put_object(
      bucket: bucket_name,
      key: object_key,
      body: file
    )
    if response.etag
      return true
    else
      return false
    end
  rescue StandardError => e
    puts "Error uploading object: #{e.message}"
    return false
  end

  def upload_to_s3()
    bucket_name = "#{ENV['S3_PRODUCT_FEED_BUCKET']}"
    object_key = @file_name

    s3_client = Aws::S3::Client.new(
      region:            ENV['S3_PRODUCT_FEED_REGION'],
      access_key_id:     ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_KEY']
    )
    
    file = File.open("./tmp/#{@file_name}", 'rb')

    if object_uploaded?(s3_client, bucket_name, object_key, file)
      puts "Object '#{object_key}' uploaded to bucket '#{bucket_name}'."
    else
      puts "Object '#{object_key}' not uploaded to bucket '#{bucket_name}'."
    end

    file.close()
  end

end