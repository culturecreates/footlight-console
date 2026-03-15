Rails.application.configure do
  config.lograge.ignore_actions = ['HealthController#show']

  config.lograge.ignore = lambda do |event|
    event.payload[:path]&.start_with?("/up")
  end
end
