redis_url = ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.on(:startup) do
    schedule = YAML.safe_load_file(Rails.root.join("config/schedule.yml"))
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end
Sidekiq.configure_client { |config| config.redis = { url: redis_url } }
