require 'spec/spec_helper'

describe FeaturedCollectionLink do
  fixtures :affiliates
  before do
    @affiliate = affiliates(:usagov_affiliate)
  end
  
  it { should validate_presence_of :title }
  it { should validate_presence_of :url }
  it { should belong_to :featured_collection }

  describe "URL should have http(s):// prefix" do
    context "when the URL does not start with http(s):// prefix" do
      url = 'usasearch.howto.gov/post/9866782725/did-you-mean-roes-or-rose'
      prefixes = %w( http https HTTP HTTPS invalidhttp:// invalidHtTp:// invalidhttps:// invalidHTtPs:// invalidHttPsS://)
      prefixes.each_with_index do |prefix, index|
        specify do
          featured_collection = FeaturedCollection.new(:title => 'Search USA Blog',
                                                       :status => 'active',
                                                       :layout => 'one column',
                                                       :publish_start_on => '07/01/2011',
                                                       :affiliate => @affiliate)
          featured_collection.featured_collection_links.build(:title => 'Did You Mean Roes or Rose?',
                                                              :url => "#{prefix}#{url}",
                                                              :position => index)
          featured_collection.save!
          featured_collection.featured_collection_links.first.url.should == "http://#{prefix}#{url}"
        end
      end
    end

    context "when the URL starts with http(s):// prefix" do
      url = 'usasearch.howto.gov/post/9866782725/did-you-mean-roes-or-rose'
      prefixes = %w( http:// https:// HTTP:// HTTPS:// )
      prefixes.each_with_index do |prefix, index|
        specify do
          featured_collection = FeaturedCollection.new(:title => 'Search USA Blog',
                                                       :status => 'active',
                                                       :layout => 'one column',
                                                       :publish_start_on => '07/01/2011',
                                                       :affiliate => @affiliate)
          featured_collection.featured_collection_links.build(:title => 'Did You Mean Roes or Rose?',
                                                              :url => "#{prefix}#{url}",
                                                              :position => index)
          featured_collection.save!
          featured_collection.featured_collection_links.first.url.should == "#{prefix}#{url}"
        end
      end
    end
  end
end
