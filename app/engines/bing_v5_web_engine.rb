class BingV5WebEngine < BingSearch
  API_ENDPOINT = '/bing/v5.0/search'.freeze
  include BingV5HostedSubscriptionKey

  self.api_endpoint = API_ENDPOINT
  self.api_cache_namespace = 'bing_v5_api'
  self.response_parser_class = BingV5WebResponseParser
end
