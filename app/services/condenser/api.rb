# app/services/condenser/api.rb
#
# Condenser API Wrapper
#
# Purpose:
#   Centralized Ruby wrapper for Condenser HTTP API endpoints.
#   Handles:
#     - path substitution
#     - query/body parameters
#     - snake_case → API camelCase conversion
#     - strict parameter validation
#
# Usage examples:
#   Condenser::API.website_events(seedurl: "example", start_date: "2015-01-01")
#   Condenser::API.property_statements(seedurl: "example", property_id: 5)

module Condenser
  module API

    ENDPOINTS = {

      # Dashboard
      dashboard_metrics: {
        method: :get,
        path: "/dashboard_metrics.json"
      },

      # Sources
      sources: {
        method: :get,
        path: "/sources.json",
        params: [:seedurl]
      },

      source: {
        method: :get,
        path: "/sources/:id.json"
      },

      # Websites
      websites: {
        method: :get,
        path: "/websites.json"
      },

      website_events: {
        method: :get,
        path: "/websites/:seedurl/events.json",
        params: [:start_date, :end_date],
        param_aliases: {
          start_date: "startDate",
          end_date: "endDate"
        }
      },

      website_resources: {
        method: :get,
        path: "/websites/:seedurl/resources.json"
      },

      # Resources
      resource: {
        method: :get,
        path: "/resources/:id.json"
      },

      create_linked_resource: {
        method: :post,
        path: "/resources.json",
        params: [:seedurl, :rdf_uri]
      },

      delete_resource: {
        method: :delete,
        path: "/resources/:id.json"
      },

      # Statements
      search_statements: {
        method: :get,
        path: "/statements.json",
        params: [:subject]
      },

      activate_statement: {
        method: :patch,
        path: "/statements/:id/activate.json"
      },

      activate_individual_statement: {
        method: :patch,
        path: "/statements/:id/activate_individual.json"
      },

      deactivate_individual_statement: {
        method: :patch,
        path: "/statements/:id/deactivate_individual.json"
      },

      reconnect_feed_statement: {
        method: :patch,
        path: "/statements/:id/reconnect_feed.json"
      },

      save_individual_statement: {
        method: :patch,
        path: "/statements/:id/save_individual.json"
      },

      refresh_rdf_uri_statements: {
        method: :post,
        path: "/statements/refresh_rdf_uri.json",
        params: [:seedurl]
      },

      property_statements: {
        method: :get,
        path: "/websites/:seedurl/events_by_property.json",
        params: [:property_id, :start_date, :end_date],
        param_aliases: {
          property_id: "property",
          start_date: "startDate",
          end_date: "endDate"
        }
      },

      # Events
      review_all_statements: {
        method: :post,
        path: "/events/:event_id/review_all_statements.json"
      }

    }.freeze

    ENDPOINTS.each do |name, endpoint|
      raise "Endpoint #{name} missing :method" unless endpoint[:method]
      raise "Endpoint #{name} missing :path" unless endpoint[:path]

      unless [:get, :post, :patch, :delete].include?(endpoint[:method])
        raise "Endpoint #{name} has invalid method #{endpoint[:method]}"
      end
    end

    # Singleton client
    def self.client
      @client ||= Condenser::Client.new
    end


    ENDPOINTS.each do |name, endpoint|

      define_singleton_method(name) do |**params|

        method        = endpoint[:method]
        path_template = endpoint[:path]

        # Extract path params from template
        path_keys = path_template.scan(/:(\w+)/).flatten.map(&:to_sym)

        # Validate required path params
        missing = path_keys - params.keys
        if missing.any?
          raise ArgumentError,
            "Missing params for #{name}: #{missing.join(', ')}"
        end

        # Validate unknown params (Ruby interface)
        allowed = (endpoint[:params] || []) + path_keys

        unknown = params.keys - allowed
        if unknown.any?
          raise ArgumentError,
            "Unknown params for #{name}: #{unknown.join(', ')}. Allowed: #{allowed.join(', ')}"
        end

        # Convert snake_case → API param names
        params = normalize_params(params, endpoint[:param_aliases])

        # Substitute path parameters
        path = path_template.gsub(/:(\w+)/) { params.delete($1.to_sym) }

        # Determine query/body
        query = method == :get ? params : nil
        body  = method != :get ? params : nil

        client.request(
          method: method,
          path: path,
          query: query,
          body: body
        )
      end
    end


    # Normalize parameters
    # --------------------
    # - removes nil values
    # - converts Ruby param names to API names
    def self.normalize_params(params, param_aliases)
      aliases = param_aliases || {}

      params.each_with_object({}) do |(key, value), normalized|
        next if value.nil?

        normalized[aliases.fetch(key, key)] = value
      end
    end


    def self.base_url
      client.base_url
    end


    # Debug helpers
    # -------------

    def self.routes
      ENDPOINTS.keys
    end


    def self.print_routes
      ENDPOINTS.each do |name, endpoint|
        puts "%-25s %-6s %s" % [
          name,
          endpoint[:method].to_s.upcase,
          endpoint[:path]
        ]
      end
    end

  end
end
