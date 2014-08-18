module Oasis
  INSTAGRAM_API_ENDPOINT = "/api/v1/instagram_profiles.json"
  FLICKR_API_ENDPOINT = "/api/v1/flickr_profiles.json"

  def self.subscribe_to_instagram(id, username)
    params = { id: id, username: username }
    post_subscription(instagram_api_url, params)
  end

  def self.subscribe_to_flickr(id, name, profile_type)
    params = { id: id, name: name, profile_type: profile_type }
    post_subscription(flickr_api_url, params)
  end

  def self.host
    yaml['host']
  end

  private

  def self.instagram_api_url
    "http://#{host}#{INSTAGRAM_API_ENDPOINT}"
  end

  def self.flickr_api_url
    "http://#{host}#{FLICKR_API_ENDPOINT}"
  end

  def self.post_subscription(endpoint, params)
    Net::HTTP.post_form(URI.parse(endpoint), params)
  rescue Exception => e
    Rails.logger.warn("Trouble posting subscription to #{endpoint} with params: #{params}: #{e}")
  end

  def self.yaml
    @@yaml ||= YAML.load_file("#{Rails.root}/config/oasis.yml")
  end

end
