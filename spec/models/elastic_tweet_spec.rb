require 'spec_helper'

describe ElasticTweet do
  fixtures :affiliates, :twitter_profiles, :languages
  let(:affiliate) { affiliates(:usagov_affiliate) }
  let(:twitter_profile) { twitter_profiles(:usagov) }

  before do
    ElasticTweet.recreate_index
    Tweet.delete_all
    now = Time.now
    Tweet.create!(:tweet_id => 1234567, :tweet_text => "Good morning, America!", :published_at => now, :twitter_profile_id => 12345)
    Tweet.create!(:tweet_id => 2345678, :tweet_text => "Good morning, America!", :published_at => now - 10.seconds, :twitter_profile_id => 2196784676)
    Tweet.create!(:tweet_id => 445621639863365632, :tweet_text => "Hello, America!", :published_at => 4.months.ago, :twitter_profile_id => 12345)
    ElasticTweet.commit
  end

  describe ".search_for" do
    describe "results structure" do
      context 'when there are results' do

        it 'should return results in an easy to access structure' do
          search = ElasticTweet.search_for(q: 'america', twitter_profile_ids: [12345, 2196784676], size: 1, offset: 1, language: 'en')
          search.total.should == 3
          search.results.size.should == 1
          search.results.first.should be_instance_of(Tweet)
          search.offset.should == 1
        end

        context 'when those results get deleted' do
          before do
            Tweet.destroy_all
            ElasticTweet.commit
          end

          it 'should return zero results' do
            search = ElasticTweet.search_for(q: 'america', twitter_profile_ids: [12345, 2196784676], size: 1, offset: 1, language: 'en')
            search.total.should be_zero
            search.results.size.should be_zero
          end
        end
      end
    end

    describe "filters" do

      context 'when Twitter profile IDs are specified' do
        it "should restrict results to the tweets with those Twitter profile IDs" do
          search = ElasticTweet.search_for(q: 'america', twitter_profile_ids: [2196784676], language: 'en')
          search.total.should == 1
          search.results.first.tweet_id.should == 2345678
        end
      end

      context 'when a date restriction is present' do
        it 'should filter out Tweets older than that date' do
          search = ElasticTweet.search_for(q: 'america', twitter_profile_ids: [12345], language: 'en', since: 3.months.ago)
          search.total.should == 1
          search.results.first.tweet_id.should == 1234567
        end
      end

      context 'when affiliate locale is not one of the custom indexed languages' do
        before do
          affiliate.locale = 'kl'
          affiliate.save!
          twitter_profile.affiliates << affiliate
          Tweet.create!(tweet_id: 90210, tweet_text: "Angebote und Superknüller der Woche",
                        published_at: Time.now, twitter_profile_id: twitter_profile.twitter_id)
          ElasticTweet.commit
        end

        it 'should do downcasing and ASCII folding only' do
          appropriate_stemming = ['superknuller', 'woche']
          appropriate_stemming.each do |query|
            ElasticTweet.search_for(q: query, twitter_profile_ids: [twitter_profile.twitter_id], language: affiliate.indexing_locale).total.should == 1
          end
        end
      end

    end

    describe "sorting" do
      it "should show newest first, by default" do
        search = ElasticTweet.search_for(q: 'america', twitter_profile_ids: [12345, 2196784676], language: 'en')
        search.total.should == 3
        search.results.collect(&:tweet_id).should == [1234567, 2345678, 445621639863365632]
      end
    end

  end

end