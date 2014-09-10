Given /^affiliate "([^"]*)" has the following document collections:$/ do |affiliate_name, table|
  affiliate = Affiliate.find_by_name affiliate_name
  table.hashes.each do |hash|
    collection = affiliate.document_collections.new(name: hash[:name])
    prefixes = hash[:prefixes].split(',')
    prefixes.each do |prefix|
      collection.url_prefixes.build(prefix: prefix)
    end
    collection.save!
    collection.navigation.update_attributes!(is_active: hash[:is_navigable] || true,
                                             position: hash[:position] || 100)
    collection.build_sitelink_generator_names!
  end
end

When /^(?:|I )add the following Collection URL Prefixes:$/ do |table|
  url_prefix_fields_count = page.all(:css, '.url-prefixes input[type="text"]').count
  table.hashes.each_with_index do |hash, index|
    click_link 'Add Another URL Prefix'
    url_prefix_label = "URL Prefix #{url_prefix_fields_count + index + 1}"
    find 'label', text: url_prefix_label
    fill_in url_prefix_label, with: hash[:url_prefix]
  end
end

