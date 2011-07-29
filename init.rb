begin
  require 'active_record'

  module ::ActiveRecord
    class Base
      # Establishes the connection to the database. Accepts a hash as input where
      # the <tt>:adapter</tt> key must be specified with the name of a database adapter (in lower-case)
      # example for regular databases (MySQL, Postgresql, etc):
      #
      #   ActiveRecord::Base.establish_connection(
      #     :adapter  => "mysql",
      #     :host     => "localhost",
      #     :username => "myuser",
      #     :password => "mypass",
      #     :database => "somedatabase"
      #   )
      #
      # Example for SQLite database:
      #
      #   ActiveRecord::Base.establish_connection(
      #     :adapter => "sqlite",
      #     :database  => "path/to/dbfile"
      #   )
      #
      # Also accepts keys as strings (for parsing from YAML for example):
      #
      #   ActiveRecord::Base.establish_connection(
      #     "adapter" => "sqlite",
      #     "database"  => "path/to/dbfile"
      #   )
      #
      # Or a URL:
      #
      #   ActiveRecord::Base.establish_connection(
      #     "postgres://myuser:mypass@localhost/somedatabase"
      #   )
      #
      # The exceptions AdapterNotSpecified, AdapterNotFound and ArgumentError
      # may be returned on an error.
      def self.establish_connection(spec = ENV["DATABASE_URL"])
        case spec
          when nil
            raise AdapterNotSpecified unless defined?(Rails.env)
            establish_connection(Rails.env)
          when ConnectionSpecification
            self.connection_handler.establish_connection(name, spec)
          when Symbol, String
            if configuration = configurations[spec.to_s]
              establish_connection(configuration)
            elsif spec.is_a?(String) && hash = connection_url_to_hash(spec)
              establish_connection(hash)
            else
              raise AdapterNotSpecified, "#{spec} database is not configured"
            end
          else
            spec = spec.symbolize_keys
            unless spec.key?(:adapter) then raise AdapterNotSpecified, "database configuration does not specify adapter" end

            begin
              require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
            rescue LoadError => e
              raise "Please install the #{spec[:adapter]} adapter: `gem install activerecord-#{spec[:adapter]}-adapter` (#{e})"
            end

            adapter_method = "#{spec[:adapter]}_connection"
            unless respond_to?(adapter_method)
              raise AdapterNotFound, "database configuration specifies nonexistent #{spec[:adapter]} adapter"
            end

            remove_connection
            establish_connection(ConnectionSpecification.new(spec, adapter_method))
        end
      end

      def self.connection_url_to_hash(url) # :nodoc:
        config = URI.parse url
        adapter = config.scheme
        adapter = "postgresql" if adapter == "postgres"
        spec = { :adapter  => adapter,
                 :username => config.user,
                 :password => config.password,
                 :port     => config.port,
                 :database => config.path.sub(%r{^/},""),
                 :host     => config.host }
        spec.reject!{ |_,value| !value }
        if config.query
          options = Hash[config.query.split("&").map{ |pair| pair.split("=") }].symbolize_keys
          spec.merge!(options)
        end
        spec
      end
    end
  end

  ::ActiveRecord::Base.establish_connection # force this connection
rescue LoadError
end
