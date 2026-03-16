module Condenser
  module API
    module EndpointsValidator

      VALID_METHODS = [:get, :post, :patch, :delete].freeze

      def self.validate!
        Condenser::API::ENDPOINTS.each do |name, endpoint|
          validate_endpoint_structure!(name, endpoint)
          validate_endpoint_contract!(name, endpoint)
        end
      end

      def self.validate_endpoint_structure!(name, endpoint)
        raise "Endpoint #{name} must be a Hash" unless endpoint.is_a?(Hash)

        raise "Endpoint #{name} missing :method" unless endpoint[:method]
        raise "Endpoint #{name} missing :path" unless endpoint[:path]

        unless VALID_METHODS.include?(endpoint[:method])
          raise "Endpoint #{name} has invalid method #{endpoint[:method]}"
        end

        endpoint[:path_keys] =
          endpoint[:path].scan(/:(\w+)/).flatten.map(&:to_sym).freeze

        # Duplicates ?
        seen = {}

        Condenser::API::ENDPOINTS.each do |name, ep|
          key = [
            ep[:method],
            ep[:path],
            ep[:params],
            ep[:param_aliases],
            ep[:body_builder]&.source_location
          ]

          if seen[key]
            raise "Duplicate endpoint operation: #{name} and #{seen[key]}"
          end

          seen[key] = name
        end
      end


      def self.validate_endpoint_contract!(name, endpoint)
        if endpoint[:params]
          overlap = endpoint[:params] & endpoint[:path_keys]
          raise "Endpoint #{name} params overlap path keys: #{overlap}" unless overlap.empty?
        end

        if endpoint[:params] && !endpoint[:params].is_a?(Array)
          raise "Endpoint #{name} params must be an Array"
        end

        if endpoint[:param_aliases] && !endpoint[:param_aliases].is_a?(Hash)
          raise "Endpoint #{name} param_aliases must be a Hash"
        end

        if endpoint[:body_builder] && !endpoint[:body_builder].respond_to?(:call)
          raise "Endpoint #{name} body_builder must respond to :call"
        end
      end

    end
  end
end
