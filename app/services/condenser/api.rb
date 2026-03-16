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
# 
# Architecture
# ------------
#
#          Console
#            ↓↑
#      Condenser::API
#            ↓↑
#  ENDPOINTS (data contracts)
#            ↓↑
#     generic executor
#            ↓↑ 
#     Condenser client
#            ↓↑
#        HTTP client
#            ↓↑
#        Condenser
#

require "cgi/util"

module Condenser
  module API

    # --------------------------------------------------
    # Endpoints: data transformations and retrieval 
    # --------------------------------------------------
    ENDPOINTS = {

      # --------------------------------------------------
      # Dashboard: overall view of websites - health
      # --------------------------------------------------
      dashboard_metrics: { method: :get, 
                          path: "/dashboard_metrics.json" },

      # --------------------------------------------------
      # Events: reviews all statements belonging to an event
      # --------------------------------------------------
      review_all_statements: {
        method: :patch,
        path: "/resources/:event_id/reviewed_all.json",
        params: [:user_name, :review_next, :seedurl],
        body_builder: ->(p) {
          body = {
            event: { status_origin: p[:user_name] }
          }

          body[:review_next] = p[:review_next] if p[:review_next]
          body[:seedurl]     = p[:seedurl] if p[:seedurl]

          body
        }.freeze
      },

      # --------------------------------------------------
      # Properties: reviews all statements associated with a property
      # --------------------------------------------------
      review_all_statements_by_property: {
        method: :patch,
        path: "/properties/:property_id/review_all_statements.json",
        params: [:user_name, :seedurl],
        body_builder: ->(p) {
          {
            status: "ok",
            status_origin: p[:user_name],
            seedurl: p[:seedurl]
          }
        }.freeze
      },

      # --------------------------------------------------
      # Resources: linked places, people and organizations
      # --------------------------------------------------
      create_linked_resource: { method: :post, 
                                path: "/resources.json", 
                                params: [:rdfs_class, :seedurl, :statements] },

      delete_resource_uri:    { method: :delete, 
                                path: "/resources/delete_uri.json", 
                                params: [:uri] },

      resource:               { method: :get, 
                                path: "/resources.json", 
                                params: [:uri] },

      website_resources:      { method: :get, 
                                path: "/websites/:seedurl/resources.json" },

      # --------------------------------------------------
      # Sources: 
      # --------------------------------------------------
      source: { method: :get, 
                path: "/sources/:id.json" },

      sources: { method: :get, 
                path: "/sources.json", 
                params: [:seedurl] },

      # --------------------------------------------------
      # Statements
      # --------------------------------------------------
      activate_individual_statement:   { method: :patch, 
                                        path: "/statements/:id/activate_individual.json" },

      activate_statement:              { method: :patch, 
                                        path: "/statements/:id/activate.json" },

      add_linked_data: {
        method: :patch,
        path: "/statements/:id/add_linked_data.json",
        params: [:user_name, :name, :rdfs_class, :uri],
        body_builder: ->(p) {
          {
            statement: {
              cache: "[\"#{p[:name]}\",\"#{p[:rdfs_class]}\",\"#{p[:uri]}\"]",
              status: "ok",
              status_origin: p[:user_name]
            }
          }
        }.freeze
      },

      deactivate_individual_statement: { method: :patch, 
                                        path: "/statements/:id/deactivate_individual.json" },

      flag_statement: {
        method: :patch,
        path: "/statements/:id.json",
        params: [:user_name],
        body_builder: ->(p) {
          {
            statement: {
              status: "problem",
              status_origin: p[:user_name]
            }
          }
        }.freeze
      },

      reconnect_feed_statement: {
        method: :patch,
        path: "/statements/:id/reconnect_feed.json",
        params: [:user_name],
        body_builder: ->(p) {
          {
            statement: {
              manual: false,
              status_origin: p[:user_name]
            }
          }
        }.freeze
      },

      refresh_rdf_uri_statements:      { method: :patch, 
                                        path: "/statements/refresh_rdf_uri.json",             
                                        params: [:rdf_uri] },

      remove_linked_data:              { 
        method: :patch, 
        path: "/statements/:id/remove_linked_data.json",
        params: [:user_name, :name, :rdfs_class, :uri],
        body_builder: ->(p) {
          {
            statement: {
              cache: "[\"#{p[:name]}\",\"#{p[:rdfs_class]}\",\"#{p[:uri]}\"]",
              status: "ok",
              status_origin: p[:user_name]
            }
          }
        }.freeze
      },

      review_statement: {
        method: :patch,
        path: "/statements/:id.json",
        params: [:user_name],
        body_builder: ->(p) {
          {
            statement: {
              status: "ok",
              status_origin: p[:user_name]
            }
          }
        }.freeze
      },

      save_individual_statement: { 
        method: :patch, 
        path: "/statements/:id.json",
        params: [:user_name, :value],
        body_builder: ->(p) {
          {
            statement: {
              cache: p[:value].to_s,
              status: "ok",
              status_origin: p[:user_name]
            }
          }
        }.freeze
      },

      save_statement:                  { method: :patch, 
                                        path: "/statements/:id.json",                          
                                        params: [:statement] },

      search_statements:               { method: :get, 
                                        path: "/statements.json",                                
                                        params: [:cache] },

      # --------------------------------------------------
      # Websites: 
      # --------------------------------------------------

      property_statements: {
        method: :get,
        path: "/websites/:seedurl/events_by_property.json",
        params: [:property_id, :start_date, :end_date],
        param_aliases: {
          property_id: "property",
          start_date: "startDate",
          end_date: "endDate"
        }.freeze
      },

      website_events: {
        method: :get,
        path: "/websites/:seedurl/events.json",
        params: [:start_date, :end_date],
        param_aliases: {
          start_date: "startDate",
          end_date: "endDate"
        }.freeze
      },

      websites: { method: :get, path: "/websites.json" }

    }.freeze

    # Initialize path_keys
    ENDPOINTS.each do |_, endpoint|
      endpoint[:path_keys] =
        endpoint[:path].scan(/:(\w+)/).flatten.map(&:to_sym).freeze
    end

    # Validate endpoints
    Condenser::API::EndpointsValidator.validate!

    # --------------------------------------------------
    # Operation
    # --------------------------------------------------
    ENDPOINTS.each do |name, endpoint|
      define_singleton_method(name) do |**params|
        execute_endpoint(name, endpoint, params)
      end
    end

    # --------------------------------------------------
    # Utilities
    # --------------------------------------------------
    def self.client
      @client ||= Condenser::Client.new
    end
    
    def self.base_url
      client.base_url
    end


    private

    def self.execute_endpoint(name, endpoint, params)
      params = params.transform_keys(&:to_sym)

      method        = endpoint[:method]
      path_template = endpoint[:path]

      # Extract path parameters
      path_keys = endpoint[:path_keys] || []

      # Validate required/allowed path params
      allowed = path_keys + Array(endpoint[:params])

      assert_no_missing_params!(name, endpoint, params)
      assert_no_unknown_params!(name, endpoint, params, allowed)

      Rails.logger.debug("[CondenserAPI] params before path substitution: #{params.inspect}")

      # Substitute path parameters
      path = path_template.gsub(/:(\w+)/) do
        value = params.delete($1.to_sym)
        CGI.escape(value.to_s)
      end

      # Normalize params 
      params = normalize_params(params, endpoint[:param_aliases])

      # Build request body
      if endpoint[:body_builder]
        body  = endpoint[:body_builder].call(params)
        query = nil
      else
        query = method == :get ? params : nil
        body  = method != :get ? params : nil
      end

      # Log 
      payload = query || body
      Rails.logger.info(
        "→ [CondenserAPI] #{name} #{method.to_s.upcase} path=#{path} params=#{params.inspect} payload=#{payload.inspect}"
      )

      # Engage! :)
      client.request(
        method: method,
        path: path,
        query: query,
        body: body
      )
    end

private

    # Normalize parameters
    # --------------------
    # - removes nil values
    # - converts Ruby param names to API names
    def self.normalize_params(params, param_aliases)
      aliases = param_aliases || {}

      params.each_with_object({}) do |(key, value), normalized|
        next if value.nil?

        normalized[aliases[key] || key] = value
      end
    end

    # Check for missings
    def self.assert_no_missing_params!(name, endpoint, params)
      missing = endpoint[:path_keys] - params.keys
      return if missing.empty?

      raise ArgumentError,
        "\n\n\t********* Missing params for #{name} (#{endpoint[:path]}): #{missing.join(', ')} *********\n"
    end

    # Check for unknowns
    def self.assert_no_unknown_params!(name, endpoint, params, allowed)
      unknown = params.keys - allowed
      return if unknown.empty?

      raise ArgumentError,
        "\n\n\t********* Unknown params for #{name} (#{endpoint[:path]}): #{unknown.join(', ')}. Allowed: #{allowed.join(', ')} *********\n"
    end

  end
end
