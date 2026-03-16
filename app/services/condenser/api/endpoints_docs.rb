module Condenser
  module API
    module EndpointsDocs

      def self.describe(name)
        endpoint = Condenser::API::ENDPOINTS[name]

        puts "Name: #{name}"
        puts "Method: #{endpoint[:method].to_s.upcase}"
        puts "Path: #{endpoint[:path]}"
        puts "Params: #{endpoint[:params] || []}"
      end

      def self.routes
        Condenser::API::ENDPOINTS.keys
      end

      def self.print_routes
        Condenser::API::ENDPOINTS.each do |name, endpoint|
          puts "%-25s %-6s %s" % [
            name,
            endpoint[:method].to_s.upcase,
            endpoint[:path]
          ]
        end
      end

      def self.endpoint_docs
        Condenser::API::ENDPOINTS.map do |name, spec|
          {
            name: name,
            method: spec[:method],
            path: spec[:path],
            params: spec[:params] || [],
            example: build_example(name, spec)
          }
        end
      end

      def self.build_example(name, spec)
        params = (spec[:params] || []).map { |p| "#{p}: <value>" }.join(", ")
        "#{name}(#{params})"
      end

      def self.print_docs
        endpoint_docs.each do |ep|
          puts
          puts ep[:name]
          puts "  #{ep[:method].to_s.upcase} #{ep[:path]}"
          puts "  params: #{ep[:params].join(', ')}"
          puts "  example:"
          puts "    Condenser::API.#{ep[:example]}"
        end
      end

    end
  end
end
