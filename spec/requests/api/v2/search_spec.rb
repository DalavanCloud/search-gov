require 'spec_helper'

describe '/api/v2/search' do
  fixtures :affiliates

  let(:affiliate) { affiliates(:usagov_affiliate) }

  context 'when there are matching results' do
    before do
      ElasticBoostedContent.recreate_index
      affiliate.boosted_contents.delete_all

      (1..2).each do |i|
        attributes = {
          title: "api v2 title manual-#{i}",
          description: "api v2 description manual-#{i}",
          url: "http://search.digitalgov.gov/manual-#{i}",
          status: 'active',
          publish_start_on: Date.current,
        }
        affiliate.boosted_contents.create! attributes
      end

      ElasticBoostedContent.commit

      ElasticFeaturedCollection.recreate_index
      affiliate.featured_collections.destroy_all

      graphic_best_bet_attributes = {
        title: 'api v2 how-to',
        status: 'active',
        publish_start_on: Date.current
      }
      graphic_best_bet = affiliate.featured_collections.build graphic_best_bet_attributes

      link_attributes = {
        title: 'api v2 title how-to-1',
        url: 'http://search.digitalgov.gov/how-to-1',
        position: 0
      }
      graphic_best_bet.featured_collection_links.build link_attributes

      graphic_best_bet.save!

      ElasticFeaturedCollection.commit

      ElasticIndexedDocument.recreate_index
      affiliate.indexed_documents.destroy_all

      (1..2).each do |i|
        attributes = {
          title: "api v2 title docs-#{i}",
          url: "http://search.digitalgov.gov/docs-#{i}",
          description: "api v2 description docs-#{i} #{'extremely long content ' * 8}",
          last_crawl_status: IndexedDocument::OK_STATUS
        }
        affiliate.indexed_documents.create! attributes
      end

      ElasticIndexedDocument.commit

      affiliate.rss_feeds.destroy_all

      rss_feed = affiliate.rss_feeds.build(name: 'RSS')
      url = 'http://search.digitalgov.gov/all.atom'
      rss_feed_url = RssFeedUrl.rss_feed_owned_by_affiliate.build(url: url)
      rss_feed_url.save!(validate: false)
      rss_feed.rss_feed_urls = [rss_feed_url]
      rss_feed.save!

      (3..4).each do |i|
        attributes = {
          title: "api v2 title news-#{i}",
          link: "http://search.digitalgov.gov/news-#{i}",
          guid: "blog-#{i}",
          description: "v2 description news-#{i}  #{'extremely long content ' * 8}",
          published_at: i.days.ago
        }
        rss_feed_url.news_items.create! attributes
      end

      ElasticNewsItem.commit

      ElasticSaytSuggestion.recreate_index
      affiliate.sayt_suggestions.delete_all


      affiliate.sayt_suggestions.create!(phrase: 'api endpoint')
      affiliate.sayt_suggestions.create!(phrase: 'api instruction')

      ElasticSaytSuggestion.commit
    end

    context 'when enable_highlighting param is not present' do
      let(:expected_hash_response) do
        fixture_path = 'spec/fixtures/json/blended/with_highlighting.json'
        JSON.parse(Rails.root.join(fixture_path).read, symbolize_names: true)
      end

      it 'returns JSON results with highlighting' do
        get '/api/v2/search', affiliate: 'usagov', query: 'api'
        expect(response.status).to eq(200)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:web][:total]).to eq(4)
        expect(hash_response[:web][:results]).to match_array(expected_hash_response[:web][:results])
        expect(hash_response[:text_best_bets]).to match_array(expected_hash_response[:text_best_bets])
        expect(hash_response[:graphic_best_bets]).to match_array(expected_hash_response[:graphic_best_bets])
        expect(hash_response[:related_search_terms]).to match_array(expected_hash_response[:related_search_terms])
      end
    end

    context 'when enable_highlighting = false' do
      let(:expected_hash_response) do
        fixture_path = 'spec/fixtures/json/blended/without_highlighting.json'
        JSON.parse(Rails.root.join(fixture_path).read, symbolize_names: true)
      end

      it 'returns JSON results without highlighting' do
        get '/api/v2/search', affiliate: 'usagov', query: 'api', enable_highlighting: 'false'
        expect(response.status).to eq(200)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:web][:total]).to eq(4)
        expect(hash_response[:web][:results]).to match_array(expected_hash_response[:web][:results])
        expect(hash_response[:text_best_bets]).to match_array(expected_hash_response[:text_best_bets])
        expect(hash_response[:graphic_best_bets]).to match_array(expected_hash_response[:graphic_best_bets])
        expect(hash_response[:related_search_terms]).to match_array(expected_hash_response[:related_search_terms])
      end
    end

    context 'when limit = 1' do
      let(:expected_hash_response) do
        fixture_path = 'spec/fixtures/json/blended/with_limit.json'
        JSON.parse(Rails.root.join(fixture_path).read, symbolize_names: true)
      end

      it 'returns JSON results without highlighting' do
        get '/api/v2/search', affiliate: 'usagov', query: 'api', limit: '1'
        puts response.body
        expect(response.status).to eq(200)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:web][:total]).to eq(4)
        expect(hash_response[:web][:results].count).to eq(1)
        expect(hash_response[:text_best_bets]).to match_array(expected_hash_response[:text_best_bets])
        expect(hash_response[:graphic_best_bets]).to match_array(expected_hash_response[:graphic_best_bets])
        expect(hash_response[:related_search_terms]).to match_array(expected_hash_response[:related_search_terms])
      end
    end

    context 'when offset = 3' do
      it 'returns JSON results without highlighting' do
        get '/api/v2/search', affiliate: 'usagov', query: 'api', offset: '2'
        expect(response.status).to eq(200)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:web][:total]).to eq(4)
        expect(hash_response[:web][:results].count).to eq(2)
        expect(hash_response[:text_best_bets]).to be_empty
        expect(hash_response[:graphic_best_bets]).to be_empty
        expect(hash_response[:related_search_terms]).to be_empty
      end
    end
  end

  context 'when one of the parameter is invalid' do
    context 'when affiliate is invalid' do
      it 'returns errors' do
        get '/api/v2/search', affiliate: 'not-usagov', query: 'api'
        expect(response.status).to eq(404)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:errors].first).to eq('affiliate not found')
      end
    end

    context 'when limit is invalid' do
      it 'returns errors' do
        get '/api/v2/search', affiliate: 'usagov', limit: '5000', query: 'api'
        expect(response.status).to eq(400)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:errors].first).to eq('limit must be between 1 and 50')
      end
    end

    context 'when offset is invalid' do
      it 'returns errors' do
        get '/api/v2/search', affiliate: 'usagov', offset: '5000', query: 'api'
        expect(response.status).to eq(400)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:errors].first).to eq('offset must be between 0 and 1000')
      end
    end

    context 'when query is blank' do
      it 'returns errors' do
        get '/api/v2/search', affiliate: 'usagov', query: ''
        expect(response.status).to eq(400)

        hash_response = JSON.parse response.body, symbolize_names: true
        expect(hash_response[:errors].first).to eq('query must be present')
      end
    end
  end
end
