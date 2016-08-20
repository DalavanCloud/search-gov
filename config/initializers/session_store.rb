redis_yml = File.realpath(File.join(File.dirname(__FILE__), '../session-redis.yml'))

redis_settings =
  if File.exists?(redis_yml)
    YAML.load(ERB.new(File.read(redis_yml)).result)[Rails.env] || raise("No Redis settings found for environment #{Rails.env}!")
  else
    Rails.logger.warn("No file #{redis_yml} found, assuming Redis server is running on localhost")
    { host: 'localhost' }
  end

UsasearchRails3::Application.config.session_store :redis_store, servers: redis_settings.reverse_merge({
  db: 2,
  key_prefix: 'usasearch:session',
}), expires_in: 7200
