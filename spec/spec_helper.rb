require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'simplecov'
SimpleCov.command_name 'RSpec'

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec'
require 'rspec/rails'
require 'remarkable'
require 'remarkable_activerecord'
require "email_spec"
require "authlogic/test_case"
require 'webrat'
require 'paperclip/matchers'
require 'rspec/autorun'

include Authlogic::TestCase

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# figure out where we are being loaded from to ensure it's only done once
if $LOADED_FEATURES.grep(/spec\/spec_helper\.rb/).any?
  begin
    raise "foo"
  rescue => e
    puts <<-MSG
  ===================================================
  It looks like spec_helper.rb has been loaded
  multiple times. Normalize the require to:

    require "spec/spec_helper"

  Things like File.join and File.expand_path will
  cause it to be loaded multiple times.

  Loaded this time from:

    #{e.backtrace.join("\n    ")}
  ===================================================
    MSG
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.include Paperclip::Shoulda::Matchers
  #config.order = 'random'

  config.before(:suite) do
    FileUtils.mkdir_p(File.join(Rails.root.to_s, 'tmp'))

    require 'test_services'
    unless ENV['TRAVIS']
      TestServices::start_redis
    end

    EmailTemplate.load_default_templates
    OutboundRateLimit.load_defaults
    TestServices::create_es_indexes
  end

  config.before(:each) do
    bing_api_path = '/json.aspx?'

    bing_common_params = {
        Adult: 'moderate',
        AppId: 'A4C32FAE6F3DB386FC32ED1C4F3024742ED30906',
        fdtrace: 1
    }.freeze

    bing_hl_params = {
        Options: 'EnableHighlighting'
    }.freeze

    common_image_search_params = bing_common_params.
        merge(bing_hl_params).
        merge(sources: 'Spell Image').freeze

    stubs = Faraday::Adapter::Test::Stubs.new
    generic_bing_image_result = Rails.root.join('spec/fixtures/json/bing/image_search/white_house.json').read

    image_search_params = common_image_search_params.merge(query: 'white house')
    stubs.get("#{bing_api_path}#{image_search_params.to_param}") { [200, {}, generic_bing_image_result] }

    image_search_params = common_image_search_params.
        merge('image.count' => 20,
              query: '(white house) language:en (scopeid:usagovall OR site:gov OR site:mil)')
    stubs.get("#{bing_api_path}#{image_search_params.to_param}") { [200, {}, generic_bing_image_result] }

    image_search_params = common_image_search_params.merge(query: '(white house) language:en (site:nonsense.gov)')
    stubs.get("#{bing_api_path}#{image_search_params.to_param}") { [200, {}, generic_bing_image_result] }

    bing_image_no_result = Rails.root.join('spec/fixtures/json/bing/image_search/no_results.json').read
    image_search_params = common_image_search_params.merge(query: '(unusual image) language:en  (site:nonsense.gov)')
    stubs.get("#{bing_api_path}#{image_search_params.to_param}") { [200, {}, bing_image_no_result] }

    generic_bing_result_no_highlight = Rails.root.join('spec/fixtures/json/bing/web_search/ira_no_highlight.json').read
    common_no_hl_web_search_params = bing_common_params.merge(sources: 'Spell Web').freeze
    no_hl_web_search_params = common_no_hl_web_search_params.
      merge(query: 'no highlighting',
            'web.offset' => 11)

    stubs.get("#{bing_api_path}#{no_hl_web_search_params.to_param}") { [200, {}, generic_bing_result_no_highlight] }

    generic_bing_result = Rails.root.join('spec/fixtures/json/bing/web_search/ira.json').read
    common_web_search_params = bing_common_params.
      merge(bing_hl_params).
      merge(sources: 'Spell Web').freeze

    web_search_params = common_web_search_params.merge(query: 'highlight enabled')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, generic_bing_result] }

    web_search_params = common_web_search_params.merge(query: 'casa blanca')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, generic_bing_result] }

    web_search_params = common_web_search_params.merge(query: '中国')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, generic_bing_result] }

    web_search_params = common_web_search_params.merge(query: 'english')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, generic_bing_result] }

    web_search_params = common_web_search_params.merge(query: '(english) language:en (site:nonsense.gov)')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, generic_bing_result] }

    page2_6results = Rails.root.join('spec/fixtures/json/bing/web_search/page2_6results.json').read
    web_search_params = common_web_search_params.
        merge(query: '(fewer) language:en (site:nonsense.gov)',
              'web.offset' => 10)
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, page2_6results] }

    total_no_results = Rails.root.join('spec/fixtures/json/bing/web_search/total_no_results.json').read
    web_search_params = common_web_search_params.merge(query: 'total_no_results')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, total_no_results] }

    two_results_1_missing_title = Rails.root.join('spec/fixtures/json/bing/web_search/2_results_1_missing_title.json').read
    web_search_params = common_web_search_params.merge(query: '2missing1')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, two_results_1_missing_title] }

    missing_urls = Rails.root.join('spec/fixtures/json/bing/web_search/missing_urls.json').read
    web_search_params = common_web_search_params.merge(query: 'missing_urls')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, missing_urls] }

    missing_descriptions = Rails.root.join('spec/fixtures/json/bing/web_search/missing_descriptions.json').read
    web_search_params = common_web_search_params.merge(query: 'missing_descriptions')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, missing_descriptions] }

    bing_no_results = Rails.root.join('spec/fixtures/json/bing/web_search/no_results.json').read

    web_search_params = common_web_search_params.merge(query: 'no_results')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, bing_no_results] }
    web_search_params = common_web_search_params.merge(query: '(no_results) language:en (site:nonsense.gov)')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, bing_no_results] }
    web_search_params = common_web_search_params.merge(query: '(Scientost) language:en (site:www100.whitehouse.gov)')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, bing_no_results] }

    bing_spelling = Rails.root.join('spec/fixtures/json/bing/web_search/spelling_suggestion.json').read
    web_search_params = common_web_search_params.merge(query: 'electro coagulation')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, bing_spelling] }

    web_search_params = common_web_search_params.merge(query: '(electro coagulation) language:en (scopeid:usagovall OR site:gov OR site:mil)')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, bing_spelling] }

    bing_spelling = Rails.root.join('spec/fixtures/json/bing/web_search/spelling_suggestion.json').read
    web_search_params = common_web_search_params.merge(query: '(electro coagulation) language:en (site:www.whitehouse.gov)')
    stubs.get("#{bing_api_path}#{web_search_params.to_param}") { [200, {}, bing_spelling] }

    oasis_api_path = "#{OasisSearch::API_ENDPOINT}?"
    oasis_image_result = Rails.root.join('spec/fixtures/json/oasis/image_search/shuttle.json').read
    image_search_params = { from: 0, query: 'shuttle', size: 10 }
    stubs.get("#{oasis_api_path}#{image_search_params.to_param}") { [200, {}, oasis_image_result] }

    google_api_path = '/customsearch/v1?'

    common_web_search_params = {
      alt: 'json',
      cx: GoogleSearch::SEARCH_CX,
      key: GoogleSearch::API_KEY,
      lr: 'lang_en',
      quotaUser: 'USASearch',
      safe: 'medium'
    }.freeze

    common_gss_api_search_params = common_web_search_params.
      merge(cx: 'my_cx',
            key: 'my_api_key')

    common_image_search_params = common_web_search_params.merge(searchType: 'image').freeze

    generic_google_image_result = Rails.root.join('spec/fixtures/json/google/image_search/obama.json').read
    image_search_params = common_image_search_params.merge(q: 'obama')
    stubs.get("#{google_api_path}#{image_search_params.to_param}") { [200, {}, generic_google_image_result] }

    generic_google_result = Rails.root.join('spec/fixtures/json/google/web_search/ira.json').read
    web_search_params = common_web_search_params.merge(q: 'highlight enabled')
    stubs.get("#{google_api_path}#{web_search_params.to_param}") { [200, {}, generic_google_result] }

    web_search_params = common_web_search_params.merge(q: 'no highlighting')
    stubs.get("#{google_api_path}#{web_search_params.to_param}") { [200, {}, generic_google_result] }

    gss_api_search_params = common_gss_api_search_params.merge(q: 'ira site:usa.gov')
    stubs.get("#{google_api_path}#{gss_api_search_params.to_param}") { [200, {}, generic_google_result] }

    gss_api_search_params = common_gss_api_search_params.
      merge(num: 5,
            q: 'ira site:usa.gov',
            start: 888)
    stubs.get("#{google_api_path}#{gss_api_search_params.to_param}") { [200, {}, generic_google_result] }

    es_web_search_params = common_web_search_params.merge(lr: 'lang_es', q: 'casa blanca')
    stubs.get("#{google_api_path}#{es_web_search_params.to_param}") { [200, {}, generic_google_result] }

    cn_web_search_params = common_web_search_params.merge(lr: 'lang_zh-cn', q: '中国')
    stubs.get("#{google_api_path}#{cn_web_search_params.to_param}") { [200, {}, generic_google_result] }

    gss_api_search_params = common_gss_api_search_params.merge(lr: 'lang_es', q: 'casa blanca site:usa.gov')
    stubs.get("#{google_api_path}#{gss_api_search_params.to_param}") { [200, {}, generic_google_result] }

    web_search_params = common_web_search_params.merge(q: 'english')
    stubs.get("#{google_api_path}#{web_search_params.to_param}") { [200, {}, generic_google_result] }

    google_no_results = Rails.root.join('spec/fixtures/json/google/web_search/no_results.json').read
    web_search_params = common_web_search_params.merge(q: 'no_results')
    stubs.get("#{google_api_path}#{web_search_params.to_param}") { [200, {}, google_no_results] }

    gss_api_search_params = common_gss_api_search_params.merge(q: 'mango smoothie site:usa.gov')
    stubs.get("#{google_api_path}#{gss_api_search_params.to_param}") { [200, {}, google_no_results] }

    google_no_next = Rails.root.join('spec/fixtures/json/google/web_search/no_next.json').read
    gss_api_search_params = common_gss_api_search_params.merge(q: 'healthy snack site:usa.gov')
    stubs.get("#{google_api_path}#{gss_api_search_params.to_param}") { [200, {}, google_no_next] }

    google_spelling = Rails.root.join('spec/fixtures/json/google/web_search/spelling_suggestion.json').read
    web_search_params = common_web_search_params.merge(q: 'electro coagulation')
    stubs.get("#{google_api_path}#{web_search_params.to_param}") { [200, {}, google_spelling] }

    gss_api_search_params = common_gss_api_search_params.merge(q: 'electro coagulation site:usa.gov')
    stubs.get("#{google_api_path}#{gss_api_search_params.to_param}") { [200, {}, google_spelling] }

    google_customcx = Rails.root.join('spec/fixtures/json/google/web_search/custom_cx.json').read
    web_search_params = common_web_search_params.merge(q: 'customcx', cx: '1234567890.abc', key: 'some_key')
    stubs.get("#{google_api_path}#{web_search_params.to_param}") { [200, {}, google_customcx] }

    azure_web_path = '/Bing/SearchWeb/v1/Web'
    common_azure_params = {
      :'$format' => 'JSON',
      :'$skip' => 0,
      :'$top' => 20,
      Market: "'en-US'",
      Query: "'healthy snack (site:usa.gov)'",
      Options: "'EnableHighlighting'"
    }
    azure_highlighting = Rails.root.join('spec/fixtures/json/azure/web_only/highlighting.json').read
    stubs.get("#{azure_web_path}?#{common_azure_params.to_param}") { [200, {}, azure_highlighting] }

    azure_params = common_azure_params.except(:Options)
    azure_no_highlighting = Rails.root.join('spec/fixtures/json/azure/web_only/no_highlighting.json').read
    stubs.get("#{azure_web_path}?#{azure_params.to_param}") { [200, {}, azure_no_highlighting] }

    azure_params = common_azure_params.
      merge(Query: "'healthy snack (site:usa.gov) (-site:www.usa.gov AND -site:kids.usa.gov)'")
    azure_no_next = Rails.root.join('spec/fixtures/json/azure/web_only/no_next.json').read
    stubs.get("#{azure_web_path}?#{azure_params.to_param}") { [200, {}, azure_no_next] }

    azure_params = common_azure_params.
      merge(Market: "'es-US'",
            Query: "'educación (site:usa.gov)'")
    azure_es_results = Rails.root.join('spec/fixtures/json/azure/web_only/es_results.json').read
    stubs.get("#{azure_web_path}?#{azure_params.to_param}") { [200, {}, azure_es_results] }

    azure_params = common_azure_params.merge(Query: "'mango smoothie (site:usa.gov)'")
    azure_no_results = Rails.root.join('spec/fixtures/json/azure/web_only/no_results.json').read
    stubs.get("#{azure_web_path}?#{azure_params.to_param}") { [200, {}, azure_no_results] }

    azure_params = common_azure_params.merge(:'$skip' => 888)
    stubs.get("#{azure_web_path}?#{azure_params.to_param}") { [200, {}, azure_no_results] }

    nutshell_success_params = {
      id: 'f6f91f185',
      jsonrpc: '2.0',
      method: 'editLead',
      params: {
        lead: {
          createdTime: '2015-02-01T05:00:00+00:00',
          customFields: { :'Site handle' => 'usasearch', :Status => 'inactive' },
          description: 'DigitalGov Search (usasearch)'
        }
      }
    }

    success_result = Rails.root.join('spec/fixtures/json/nutshell/edit_lead_response.json').read

    nutshell_error_params = {
      id: 'f6f91f185',
      jsonrpc: '2.0',
      method: 'editLead',
      params: {
        lead: {
          createdTime: '2015-02-01T05:00:00+00:00',
          customFields: { :'Bad field' => 'usasearch' },
          description: 'DigitalGov Search (usasearch)'
        }
      }
    }

    error_result = Rails.root.join('spec/fixtures/json/nutshell/edit_lead_response_with_error.json').read
    stubs.post(NutshellClient::ENDPOINT) do |env|
      case env[:body]
      when nutshell_success_params
        [200, {}, success_result]
      when nutshell_error_params
        [400, {}, error_result]
      end
    end

    test = Faraday.new do |builder|
      builder.adapter :test, stubs
      builder.response :rashify
      builder.response :json
    end

    #FIXME: this is in here just to get rcov coverage on SearchApiConnection
    params = { affiliate: 'wh', index: 'web', query: 'obama' }
    SearchApiConnection.new('myapi', 'http://search.usa.gov').get('/api/search.json', params)
    RateLimitedSearchApiConnection.new('rate_limited_api', 'http://search.usa.gov').get('/api/search.json', params)
    BasicAuthSearchApiConnection.new('basic_auth_api', 'http://search.usa.gov').get('/api/search.json', params.merge(auth_credentials: { password: 'mypass' }))
    NutshellClient::NutshellApiConnection.new

    Faraday.stub!(:new).and_return test
  end

  config.after(:suite) do
    TestServices::delete_es_indexes
    TestServices::stop_redis unless ENV['TRAVIS']
  end
end

Webrat.configure do |config|
  config.mode = :rails
end
