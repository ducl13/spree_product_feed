require 'libxml'

class Renderer::Products
  def self.create_xml_header(url_options, current_store)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss xmlns:g="http://base.google.com/ns/1.0" version="2.0">
        <channel>
          <title>#{current_store.name}</title>
          <link>#{current_store.url}</link>
          <description>Find out about new products first! Always be in the know when new products become available</description>
          <language>#{generate_language_xml(current_store)}</language>
    XML
  end

  def self.generate_language_xml(current_store)
    if defined?(current_store.default_locale) && !current_store.default_locale.nil?
      current_store.default_locale.downcase
    else
      "en-us"
    end
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

    <<~XML
      <item>
        <g:id>#{current_store.id.to_s + "-" + product.id.to_s}</g:id>
        #{ product.property("g:title").present? ? "" : create_node("g:title", current_store.name + ' ' + product.name) }
        <g:condition>new</g:condition>
        #{ 
          if product.property("g:description").present?
            ""
          else
            if product.respond_to?(:short_description) && product.short_description.present?
              create_node("g:description", product.short_description)
            elsif product.description.present?
             create_node("g:description", product.description)
            else
              create_node("g:description", product.meta_description)
            end
          end
        }
        #{create_node("g:link", product_url(url_options, product))}
        #{ 
          product.images&.map.with_index do |image, index|
            if index == 0
              create_node("g:image_link", image.my_cf_image_url(:large))
            else
             create_node("g:additional_image_link", image.my_cf_image_url(:large))
            end
          end.join("\n")
        }
        <g:availability>#{product.in_stock? ? "in stock" : "out of stock"}</g:availability>
        #{ 
          if product.on_sale?
            create_node("g:price", sprintf("%.2f", product.original_price) + " " + current_currency)
            create_node("g:sale_price", sprintf("%.2f", product.price) + " " + current_currency)
          else
            create_node("g:price", sprintf("%.2f", product.original_price) + " " + current_currency)
          end
        }
        #{create_node("g:shipping_weight", sprintf("%.2f", product.weight) + " lb")}
        #{create_node("g:brand", current_store.name)}
        #{create_node("g:" + product.unique_identifier_type, product.unique_identifier)}
        #{create_node("g:sku", product.sku)}
        <g:product_type>#{create_node("g:product_type", google_product_type(product))}</g:product_type>
        #{
          unless product.product_properties.blank?
            props(product)
          end
        }
      </item>
    XML
  end

  def self.render_variant_xml(url_options, current_store, current_currency, product, variant)
      options_xml_hash = Spree::Variants::XmlFeedOptionsPresenter.new(variant).xml_options

    <<~XML
          <item>
            <g:id>#{(current_store.id.to_s + "-" + product.id.to_s + "-" + variant.id.to_s).downcase}</g:id>
            #{product.property("g:title").present? ? "" : create_node("g:title", current_store.name + ' ' + product.name + ' ' + options_xml_hash.first.presentation)}
            <g:condition>new</g:condition>
            #{ 
              if product.property("g:description").present?
                ""
              else
                if product.respond_to?(:short_description) && product.short_description.present?
                 create_node("g:description", product.short_description)
                elsif product.description.present?
                  create_node("g:description", product.description)
                else
                  create_node("g:description", product.meta_description)
                end
              end
            }
            #{create_node("g:link", product_url(url_options, product) + "?variant=" + variant.id.to_s)}
            #{ 
              (product.images.to_a + variant.images.to_a).map.with_index do |image, index|
                if index == 0
                  create_node("g:image_link", image.my_cf_image_url(:large))
                elsif !product.images.blank? && !product.images.include?(image)
                  create_node("g:additional_image_link", image.my_cf_image_url(:large))
                end
              end.join("\n")
            }
            <g:availability>#{product.in_stock? ? "in stock" : "out of stock"}</g:availability>
            #{ 
              if variant.on_sale?
                create_node("g:price", sprintf("%.2f", variant.original_price) + " " + current_currency)
                create_node("g:sale_price", sprintf("%.2f", variant.price) + " " + current_currency)
              else
                create_node("g:price", sprintf("%.2f", variant.original_price) + " " + current_currency)
              end
            }
            #{create_node("g:shipping_weight", sprintf("%.2f", variant.weight) + " lb")}
            #{create_node("g:brand", current_store.name)}
            #{create_node("g:" + variant.unique_identifier_type, product.unique_identifier)}
            #{create_node("g:sku", variant.sku)}
            <g:item_group_id>#{(current_store.id.to_s + "-" + product.id.to_s).downcase}</g:item_group_id>
            #{create_node("g:product_type", google_product_type(product))}
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
            #{
              unless product.product_properties.blank?
                props(product)
              end
            }
          </item>
    XML
  end

  def self.create_node(name, value=nil, options=nil)
    node = LibXML::XML::Node.new(name)
    node.content = value.to_s unless value.nil?
    if options
      attributes = options.delete(:attributes)
      add_attributes(node, attributes) if attributes
    end
    node
  end

  def self.props(item, product)
    product.product_properties.each do |product_property|
      if product_property.property.presentation.downcase == "product_feed"
        create_node(product_property.property.name.downcase, product_property.value)
      end
    end
  end

  def self.product_url(url_options, product)
    url = url_options["host"]
    url += ":#{url_options['port']}" if url_options["port"]
    "#{url}/products/#{product.slug}"
  end
end