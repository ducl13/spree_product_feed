require 'libxml'

class Renderer::Products
  def self.create_xml_header(url_options, current_store)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss xmlns:g="http://base.google.com/ns/1.0" version="2.0">
        <channel>
          <title>#{current_store.name}</title>
          <link>#{current_store.url}</link>
          <description>Find out about new products first!</description>
          <language>en-us</language>
    XML
  end

  def self.create_xml_footer
    "</channel></rss>"
  end

  def self.xml_batch(url_options, current_store, current_currency, products)
    batch_xml = ""
    products.each_with_index do |product, index|
      next unless product.feed_active?

      if product.variants_and_option_values(current_currency).any?
        product.variants.each do |variant|
          next unless variant.show_in_product_feed?
          batch_xml << render_variant_xml(url_options, current_store, current_currency, product, variant)
        end
      else
        batch_xml << render_product_xml(url_options, current_store, current_currency, product)
      end
    end
    batch_xml
  end

  def self.render_product_xml(url_options, current_store, current_currency, product)
    # Simplified XML generation for a product
    base_url = url_options[:host] || "http://naturesflavors.localhost:3000"
    product_url = base_url + product_url(url_options, product)

    <<~XML
      <item>
        <g:id>#{current_store.id.to_s + "-" + product.id.to_s}</g:id>
        #{ product.property("g:title").present? ? "<g:title>#{product.property('g:title')}</g:title>" : "<g:title>#{current_store.name + ' ' + product.name}</g:title>" }
        <g:condition>new</g:condition>
        #{ 
          if product.property("g:description").present?
            ""
          else
            if product.respond_to?(:short_description) && product.short_description.present?
              "<g:description>#{product.short_description}</g:description>"
            elsif product.description.present?
              "<g:description>#{product.description}</g:description>"
            else
              "<g:description>#{product.meta_description}</g:description>"
            end
          end
        }
        <g:link>#{ product_url}</g:link>
        #{ 
          product.images&.map.with_index do |image, index|
            if index == 0
              "<g:image_link>#{image.my_cf_image_url(:large)}</g:image_link>"
            else
              "<g:additional_image_link>#{image.my_cf_image_url(:large)}</g:additional_image_link>"
            end
          end.join("\n")
        }
        <g:availability>#{product.in_stock? ? "in stock" : "out of stock"}</g:availability>
        #{ 
          if product.on_sale?
            "<g:price>#{sprintf('%.2f', product.original_price)} #{current_currency}</g:price>\n<g:sale_price>#{sprintf('%.2f', product.price)} #{current_currency}</g:sale_price>"
          else
            "<g:price>#{sprintf('%.2f', product.original_price)} #{current_currency}</g:price>"
          end
        }
        <g:shipping_weight>#{sprintf('%.2f', product.weight)} lb</g:shipping_weight>
        <g:brand>#{current_store.name}</g:brand>
        <g:#{product.unique_identifier_type}>#{product.unique_identifier}</g:#{product.unique_identifier_type}>
        <g:sku>#{product.sku}</g:sku>
        <g:product_type>#{google_product_type(product)}</g:product_type>
        <product_properties>#{product.product_properties.map { |pp| "<product_feed_property><name>#{pp.property.name.downcase}</name><value>#{pp.value}</value></product_feed_property>" if pp.property.presentation.downcase == 'product_feed' }.join("\n")}</product_properties>
      </item>
    XML
  end

  def self.render_variant_xml(url_options, current_store, current_currency, product, variant)
      options_xml_hash = Spree::Variants::XmlFeedOptionsPresenter.new(variant).xml_options
      base_url = url_options[:host] || "http://naturesflavors.localhost:3000"
      product_url = base_url + product_url(url_options, product) + "?variant=" + variant.id.to_s

    <<~XML
          <item>
            <g:id>#{(current_store.id.to_s + "-" + product.id.to_s + "-" + variant.id.to_s).downcase}</g:id>
            #{product.property("g:title").present? ? "" : "<g:title>#{current_store.name + ' ' + product.name + ' ' + options_xml_hash.first.presentation}</g:title>"}
            <g:condition>new</g:condition>
            #{ 
              if product.property("g:description").present?
                ""
              else
                if product.respond_to?(:short_description) && product.short_description.present?
                  "<g:description>#{product.short_description}</g:description>"
                elsif product.description.present?
                  "<g:description>#{product.description}</g:description>"
                else
                  "<g:description>#{product.meta_description}</g:description>"
                end
              end
            }
            <g:link>#{product_url}</g:link>
            #{ 
              (product.images.to_a + variant.images.to_a).map.with_index do |image, index|
                if index == 0
                  "<g:image_link>#{image.my_cf_image_url(:large)}</g:image_link>"
                elsif !product.images.blank? && !product.images.include?(image)
                  "<g:additional_image_link>#{image.my_cf_image_url(:large)}</g:additional_image_link>"
                end
              end.join("\n")
            }
            <g:availability>#{product.in_stock? ? "in stock" : "out of stock"}</g:availability>
            #{ 
              if variant.on_sale?
                "<g:price>#{sprintf('%.2f', variant.original_price)} #{current_currency}</g:price>\n<g:sale_price>#{sprintf('%.2f', variant.price)} #{current_currency}</g:sale_price>"
              else
                "<g:price>#{sprintf('%.2f', variant.original_price)} #{current_currency}</g:price>"
              end
            }
            <g:shipping_weight>#{sprintf('%.2f', variant.weight)} lb</g:shipping_weight>
            <g:brand>#{current_store.name}</g:brand>
            <g:#{variant.unique_identifier_type}>#{product.unique_identifier}</g:#{variant.unique_identifier_type}>
            <g:sku>#{variant.sku}</g:sku>
            <g:item_group_id>#{(current_store.id.to_s + "-" + product.id.to_s).downcase}</g:item_group_id>
            <g:product_type>#{google_product_type(product)}</g:product_type>
            <g:custom_label_0>#{product.feed_category}</g:custom_label_0>
            #{ 
              options_xml_hash.each_with_index.map do |ops, index|
                if ops.option_type[:name] == "color"
                  "<g:#{ops.option_type.presentation.downcase.parameterize(separator: '_')}>#{ops.name}</g>\n<g:custom_label_#{index+1}>#{ops.name}</g:custom_label_#{index+1}>" unless (index+1) > 5
                else
                  "<g:size>#{ops.presentation}</g:size>\n  <g:custom_label_#{index+1}>#{ops.presentation}</g:custom_label_#{index+1}>" unless (index+1) > 5
                end
              end.join("\n")
            }
            <product_properties>#{product.product_properties.map { |pp| "<product_feed_property><name>#{pp.property.name.downcase}</name><value>#{pp.value}</value></product_feed_property>" if pp.property.presentation.downcase == 'product_feed' }.join("\n")}</product_properties>
          </item>
    XML
  end

  def self.product_url(url_options, product)
    url = url_options["host"]
    url += ":#{url_options['port']}" if url_options["port"]
    "#{url}/products/#{product.slug}"
  end
end