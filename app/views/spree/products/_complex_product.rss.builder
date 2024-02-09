xml.tag!("g:id", (current_store.id.to_s + "-" + product.id.to_s + "-" + variant.id.to_s).downcase)

unless product.property("g:title").present?
  xml.tag!("g:title", product.name)
end

unless product.property("g:description").present?
  if product.respond_to?(:short_description) && product.short_description.present?
    xml.tag!("g:description", product.short_description)
  elsif product.description.present?
    xml.tag!("g:description", product.description)
  else
    xml.tag!("g:description", product.meta_description)
  end
end

xml.tag!("g:link", spree.product_url(product) + "?variant=" + variant.id.to_s)
xml.tag!("g:image_link", product.variant_images.present? ? product.variant_images.first.my_cf_image_url("large") : product.images.first.my_cf_image_url("large"))
xml.tag!("g:availability", variant.in_stock? ? "in stock" : "out of stock")

if defined?(variant.compare_at_price) && !variant.compare_at_price.nil?
  if variant.compare_at_price > product.price
    xml.tag!("g:price", variant.compare_at_price.to_s + " " + current_currency)
    xml.tag!("g:sale_price", variant.price_in(current_currency).amount.to_s + " " + current_currency)
  else
    xml.tag!("g:price", variant.price_in(current_currency).amount.to_s + " " + current_currency)
  end
else
  xml.tag!("g:price", variant.price_in(current_currency).amount.to_s + " " + current_currency)
end

xml.tag!("g:" + variant.unique_identifier_type, product.unique_identifier)
xml.tag!("g:sku", variant.sku)
xml.tag!("g:item_group_id", (current_store.id.to_s + "-" + product.id.to_s).downcase)
xml.tag!("g:product_type", google_product_type(product))
xml.tag!("g:custom_label_0", product.feed_category)

options_xml_hash = Spree::Variants::XmlFeedOptionsPresenter.new(variant).xml_options
options_xml_hash.each_with_index do |ops, index|
  if ops.option_type[:name] == "color"
    xml.tag!("g:" + ops.option_type.presentation.downcase.parameterize(separator: '_'), ops.name)
    xml.tag!("g:custom_label_" + (index+1).to_s, ops.name) unless (index+1) > 5
  else
    xml.tag!("g:" + ops.option_type.presentation.downcase.parameterize(separator: '_'), ops.presentation)
    xml.tag!("g:custom_label_" + (index+1).to_s, ops.presentation) unless (index+1) > 5
  end
end

unless product.product_properties.blank?
  xml << render(partial: "props", locals: {product: product})
end
