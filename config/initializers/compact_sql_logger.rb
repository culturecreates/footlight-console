ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|

  sql = payload[:sql]

  # skip noise
  next if payload[:name] == "SCHEMA"
  next if sql.include?("sqlite_version")
  next if sql.include?("schema_migrations")

  duration = ((finish - start) * 1000).round(2)

  name = payload[:name].presence || "SQL"

  Rails.logger.info("[SQL #{name}] #{duration}ms #{sql.squish}")
end
