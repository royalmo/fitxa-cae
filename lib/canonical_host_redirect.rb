# frozen_string_literal: true

class CanonicalHostRedirect
  PERMANENT_REDIRECT = 301

  def initialize(app, redirect_hosts:, target_host:, target_protocol: "https")
    @app = app
    @redirect_hosts = normalize_hosts(redirect_hosts)
    @target_host = normalize_host(target_host)
    @target_protocol = normalize_protocol(target_protocol)
  end

  def call(env)
    request = Rack::Request.new(env)

    if redirect?(request)
      [
        PERMANENT_REDIRECT,
        {
          "location" => "#{@target_protocol}://#{@target_host}#{request.fullpath}",
          "content-type" => "text/html; charset=utf-8",
          "cache-control" => "no-cache"
        },
        []
      ]
    else
      @app.call(env)
    end
  end

  private
    def redirect?(request)
      @target_host && @redirect_hosts.include?(normalize_host(request.host))
    end

    def normalize_hosts(hosts)
      Array(hosts)
        .flat_map { |host| host.to_s.split(",") }
        .filter_map { |host| normalize_host(host) }
    end

    def normalize_host(host)
      normalized = host.to_s.strip.downcase.delete_suffix(".")
      normalized.empty? ? nil : normalized
    end

    def normalize_protocol(protocol)
      normalized = protocol.to_s.strip.delete_suffix("://").delete_suffix(":")
      normalized.empty? ? "https" : normalized
    end
end
