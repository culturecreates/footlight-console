# config/initializers/route_sanity_check.rb

# Warn about duplicate or overlapping routes during boot

Rails.application.config.after_initialize do
  routes = Rails.application.routes.routes

  seen = {}

  routes.each do |route|

    path = route.path.spec.to_s.sub("(.:format)", "")
    verb = route.verb.source

    # Ignore internal Rails routes
    next if path.start_with?("/rails/")

    key = "#{verb} #{path}"

    controller = route.defaults[:controller]
    action     = route.defaults[:action]

    if seen[key]
      Rails.logger.warn("⚠️ Duplicate route detected: #{key}")
      Rails.logger.warn("   -> #{controller}##{action}")

      raise "Duplicate route detected: #{key}" if Rails.env.development?
    else
      seen[key] = true
    end
  end


  ############################################################
  # Detect dynamic ID routes (useful for auditing)
  ############################################################

  routes.each do |route|
    path = route.path.spec.to_s.sub("(.:format)", "")

    next if path.start_with?("/rails/")

    if path.include?(":id") && path.include?("/statements/")
      Rails.logger.info("Dynamic statement route: #{path}")
    end
  end

  ############################################################
  # Detect shadowed routes (static paths hidden by dynamic)
  ############################################################

  routes_list = routes.map do |route|
    {
      path: route.path.spec.to_s.sub("(.:format)", ""),
      verb: route.verb.source,
      controller: route.defaults[:controller],
      action: route.defaults[:action]
    }
  end

  routes_list.each_with_index do |route_a, i|
    next unless route_a[:path].include?(":")

    routes_list[(i + 1)..].each do |route_b|
      next if route_b[:path].include?(":") # skip dynamic targets

      dynamic_pattern = route_a[:path]
        .gsub(/:\w+/, "[^/]+")
        .gsub("/", "\\/")

      regex = Regexp.new("^#{dynamic_pattern}$")

      if regex.match?(route_b[:path])
        Rails.logger.warn(
          "⚠️ Route shadowing detected:\n" \
          "  #{route_b[:verb]} #{route_b[:path]} may be hidden by\n" \
          "  #{route_a[:verb]} #{route_a[:path]}"
        )

        raise "Shadowed route detected: #{route_b[:path]}" if Rails.env.development?
      end
    end
  end

end