# coding: utf-8
require 'spec_helper'

describe ElasticFeaturedCollection do
  fixtures :affiliates
  let(:affiliate) { affiliates(:basic_affiliate) }

  before do
    ElasticFeaturedCollection.recreate_index
    affiliate.featured_collections.destroy_all
    affiliate.locale = 'en'
  end

  describe ".search_for" do
    describe "results structure" do
      context 'when there are results' do
        before do
          affiliate.featured_collections.create!(title: 'Tropical Hurricane Names',
                                                 status: 'active',
                                                 layout: 'one column',
                                                 publish_start_on: Date.current)
          affiliate.featured_collections.create!(title: 'More Hurricane names involving tropical',
                                                 status: 'active',
                                                 layout: 'one column',
                                                 publish_start_on: Date.current)
          ElasticFeaturedCollection.commit
        end

        it 'should return results in an easy to access structure' do
          search = ElasticFeaturedCollection.search_for(q: 'Tropical', affiliate_id: affiliate.id, size: 1, offset: 1, language: affiliate.locale)
          search.total.should == 2
          search.results.size.should == 1
          search.results.first.should be_instance_of(FeaturedCollection)
          search.offset.should == 1
        end

        context 'when those results get deleted' do
          before do
            affiliate.featured_collections.destroy_all
            ElasticFeaturedCollection.commit
          end

          it 'should return zero results' do
            search = ElasticFeaturedCollection.search_for(q: 'hurricane', affiliate_id: affiliate.id, size: 1, offset: 1, language: affiliate.locale)
            search.total.should be_zero
            search.results.size.should be_zero
          end
        end
      end

    end
  end

  describe "highlighting results" do
    before do
      featured_collection = affiliate.featured_collections.build(title: 'Tropical Hurricane Names',
                                                                 status: 'active',
                                                                 layout: 'one column',
                                                                 publish_start_on: Date.current)
      featured_collection.featured_collection_links.build(title: 'Worldwide Tropical Cyclone Names Part1',
                                                          url: 'http://www.nhc.noaa.gov/aboutnames.shtml',
                                                          position: '0')
      featured_collection.featured_collection_links.build(title: 'Worldwide Tropical Cyclone Names Part2',
                                                          url: 'http://www.nhc.noaa.gov/aboutnames2.shtml',
                                                          position: '1')
      featured_collection.save!
      ElasticFeaturedCollection.commit
    end

    context 'when no highlight param is sent in' do
      it 'should highlight appropriate fields with <strong> by default' do
        search = ElasticFeaturedCollection.search_for(q: 'Tropical', affiliate_id: affiliate.id, language: affiliate.locale)
        first = search.results.first
        first.title.should == "<strong>Tropical</strong> Hurricane Names"
        first.featured_collection_links.each do |fcl|
          fcl.title.should match(%r(Worldwide <strong>Tropical</strong>))
        end
      end
    end

    context 'when field has HTML entity like an ampersand' do
      before do
        featured_collection = affiliate.featured_collections.build(title: 'Peas & Carrots',
                                                                   status: 'active',
                                                                   layout: 'one column',
                                                                   publish_start_on: Date.current)
        featured_collection.featured_collection_links.build(title: 'highlighting and entities',
                                                            url: 'http://www.nhc.noaa.gov/aboutnames.shtml',
                                                            position: '0')
        featured_collection.save!
        ElasticFeaturedCollection.commit
      end

      it 'should escape the entity but show the highlight' do
        search = ElasticFeaturedCollection.search_for(q: 'carrot', affiliate_id: affiliate.id, language: affiliate.locale)
        first = search.results.first
        first.title.should == "Peas &amp; <strong>Carrots</strong>"
        search = ElasticFeaturedCollection.search_for(q: 'entity', affiliate_id: affiliate.id, language: affiliate.locale)
        first = search.results.first
        first.title.should == "Peas &amp; Carrots"
      end
    end

    context 'when highlight is turned off' do
      it 'should not highlight matches' do
        search = ElasticFeaturedCollection.search_for(q: 'Tropical', affiliate_id: affiliate.id, language: affiliate.locale, highlighting: false)
        first = search.results.first
        first.title.should == "Tropical Hurricane Names"
        first.featured_collection_links.each do |fcl|
          fcl.title.should match(%r(Worldwide Tropical Cyclone))
        end
      end
    end

    context 'when title is really long' do
      before do
        long_title = "President Obama overcame furious lobbying by big banks to pass Dodd-Frank Wall Street Reform, to prevent the excessive risk-taking that led to a financial crisis while providing protections to American families for their mortgages and credit cards."
        affiliate.featured_collections.create!(title: long_title, status: 'active', layout: 'one column', publish_start_on: Date.current)
        ElasticFeaturedCollection.commit
      end

      it 'should show everything in a single fragment' do
        search = ElasticFeaturedCollection.search_for(q: 'president credit cards', affiliate_id: affiliate.id, language: affiliate.locale)
        first = search.results.first
        first.title.should == "<strong>President</strong> Obama overcame furious lobbying by big banks to pass Dodd-Frank Wall Street Reform, to prevent the excessive risk-taking that led to a financial crisis while providing protections to American families for their mortgages and <strong>credit</strong> <strong>cards</strong>."
      end
    end
  end

  describe "filters" do
    context "when there are active and inactive featured collections" do
      before do
        affiliate.featured_collections.create!(title: 'Tropical Hurricane Names', status: 'active',
                                               layout: 'one column', publish_start_on: Date.current)
        affiliate.featured_collections.create!(title: 'Retired Tropical Hurricane names', status: 'inactive',
                                               layout: 'one column', publish_start_on: Date.current)
        ElasticFeaturedCollection.commit
      end

      it "should return only active Featured Collections" do
        search = ElasticFeaturedCollection.search_for(q: 'Tropical', affiliate_id: affiliate.id, size: 2, language: affiliate.locale)
        search.total.should == 1
        search.results.first.is_active?.should be_true
      end
    end

    context 'when there are matches across affiliates' do
      let(:other_affiliate) { affiliates(:power_affiliate) }

      before do
        other_affiliate.locale = 'en'
        values = { title: 'Tropical Hurricane Names', status: 'active', layout: 'one column', publish_start_on: Date.current }
        affiliate.featured_collections.create!(values)
        other_affiliate.featured_collections.create!(values)

        ElasticFeaturedCollection.commit
      end

      it "should return only matches for the given affiliate" do
        search = ElasticFeaturedCollection.search_for(q: 'Tropical', affiliate_id: affiliate.id, language: affiliate.locale)
        search.total.should == 1
        search.results.first.affiliate.name.should == affiliate.name
      end
    end

    context 'when publish_start_on date has not been reached' do
      before do
        affiliate.featured_collections.create!(title: 'Current Tropical Hurricane Names', status: 'active',
                                               layout: 'one column', publish_start_on: Date.current)
        affiliate.featured_collections.create!(title: 'Future Tropical Hurricane names', status: 'active',
                                               layout: 'one column', publish_start_on: Date.tomorrow)
        ElasticFeaturedCollection.commit
      end

      it 'should omit those results' do
        search = ElasticFeaturedCollection.search_for(q: 'Tropical', affiliate_id: affiliate.id, size: 2, language: affiliate.locale)
        search.total.should == 1
        search.results.first.title.should =~ /^Current/
      end
    end

    context 'when publish_end_on date has been reached' do
      before do
        affiliate.featured_collections.create!(title: 'Current Tropical Hurricane Names', status: 'active',
                                               layout: 'one column', publish_start_on: Date.current)
        affiliate.featured_collections.create!(title: 'Expired Tropical Hurricane names', status: 'active',
                                               layout: 'one column', publish_start_on: 1.week.ago.to_date, publish_end_on: Date.current)
        ElasticFeaturedCollection.commit
      end

      it 'should omit those results' do
        search = ElasticFeaturedCollection.search_for(q: 'Tropical', affiliate_id: affiliate.id, size: 2, language: affiliate.locale)
        search.total.should == 1
        search.results.first.title.should =~ /^Current/
      end
    end
  end

  describe "recall" do
    before do
      featured_collection = affiliate.featured_collections.build(title: 'Obamå',
                                                                 status: 'active',
                                                                 layout: 'one column',
                                                                 publish_start_on: Date.current)
      featured_collection.featured_collection_links.build(title: 'Bideñ',
                                                          url: 'http://www.nhc.noaa.gov/aboutnames2.shtml',
                                                          position: 0)
      featured_collection.featured_collection_links.build(title: 'Our affiliates and customers are terrible at spelling',
                                                          url: 'http://www.nhc.noaa.gov/aboutnames3.shtml',
                                                          position: 1)
      featured_collection.featured_collection_links.build(title: 'Especially park names like yosemite',
                                                          url: 'http://www.nhc.noaa.gov/aboutname43.shtml',
                                                          position: 2)
      featured_collection.featured_collection_links.build(title: 'And the occasional similar spanish/english word like publications',
                                                          url: 'http://www.nhc.noaa.gov/aboutname4.shtml',
                                                          position: 3)
      featured_collection.featured_collection_keywords.build(value: 'Corazón')
      featured_collection.featured_collection_keywords.build(value: 'fair pay act')
      featured_collection.save!
      ElasticFeaturedCollection.commit
    end

    describe 'keywords' do
      it 'should be case insensitive' do
        ElasticFeaturedCollection.search_for(q: 'cORAzon', affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
      end

      it 'should perform ASCII folding' do
        ElasticFeaturedCollection.search_for(q: 'coràzon', affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
      end

      it 'should only match full keyword phrase' do
        ElasticFeaturedCollection.search_for(q: 'fair pay act', affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
        ElasticFeaturedCollection.search_for(q: 'fair pay', affiliate_id: affiliate.id, language: affiliate.locale).total.should be_zero
      end
    end

    describe "title and link titles" do
      it 'should be case insentitive' do
        ElasticFeaturedCollection.search_for(q: 'OBAMA', affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
        ElasticFeaturedCollection.search_for(q: 'BIDEN', affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
      end

      it 'should perform ASCII folding' do
        ElasticFeaturedCollection.search_for(q: 'øbåmà', affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
        ElasticFeaturedCollection.search_for(q: 'bîdéÑ', affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
      end

      context "when query contains problem characters" do
        ['"   ', '   "       ', '+++', '+-', '-+'].each do |query|
          specify { ElasticFeaturedCollection.search_for(q: query, affiliate_id: affiliate.id, language: affiliate.locale).total.should be_zero }
        end

        %w(+++obama --obama +-obama).each do |query|
          specify { ElasticFeaturedCollection.search_for(q: query, affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1 }
        end
      end

      context 'when affiliate is English' do
        before do
          featured_collection = affiliate.featured_collections.build(title: 'The affiliate interns use powerful engineering computers',
                                                                     status: 'active',
                                                                     layout: 'one column',
                                                                     publish_start_on: Date.current)
          featured_collection.featured_collection_links.build(title: 'Organic feet symbolize with oceanic views',
                                                              url: 'http://www.nhc.noaa.gov/aboutnames2.shtml',
                                                              position: 0)
          featured_collection.save!
          ElasticFeaturedCollection.commit
        end

        it 'should do minimal English stemming with basic stopwords' do
          appropriate_stemming = ['The computer with an intern and affiliates', 'Organics symbolizes a the view']
          appropriate_stemming.each do |query|
            ElasticFeaturedCollection.search_for(q: query, affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
          end
          overstemmed_queries = %w{internal internship symbolic ocean organ computing powered engine}
          overstemmed_queries.each do |query|
            ElasticFeaturedCollection.search_for(q: query, affiliate_id: affiliate.id, language: affiliate.locale).total.should be_zero
          end
        end
      end

      context 'when affiliate is Spanish' do
        before do
          affiliate.locale = 'es'
          featured_collection = affiliate.featured_collections.build(title: 'Leyes y el rey',
                                                                     status: 'active',
                                                                     layout: 'one column',
                                                                     publish_start_on: Date.current)
          featured_collection.featured_collection_links.build(title: 'Beneficios y ayuda financiera verificación',
                                                              url: 'http://www.nhc.noaa.gov/aboutnames2.shtml',
                                                              position: 0)
          featured_collection.featured_collection_links.build(title: 'Lotería de visas 2015',
                                                              url: 'http://www.nhc.noaa.gov/aboutnames3.shtml',
                                                              position: 1)
          featured_collection.save!
          ElasticFeaturedCollection.commit
        end

        it 'should do minimal Spanish stemming with basic stopwords' do
          appropriate_stemming = ['ley con reyes', 'financieros']
          appropriate_stemming.each do |query|
            ElasticFeaturedCollection.search_for(q: query, affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
          end
          overstemmed_queries = %w{verificar finanzas}
          overstemmed_queries.each do |query|
            ElasticFeaturedCollection.search_for(q: query, affiliate_id: affiliate.id, language: affiliate.locale).total.should be_zero
          end
        end
      end
    end

    describe "misspellings and fuzzy matches" do
      it 'should return results for slight misspellings after the first two characters' do
        oops = %w{yossemite yosemity speling publicaciones}
        oops.each do |misspeling|
          ElasticFeaturedCollection.search_for(q: misspeling, affiliate_id: affiliate.id, language: affiliate.locale).total.should == 1
        end
      end
    end
  end

  it_behaves_like "an indexable"

end