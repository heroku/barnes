# Copyright (c) 2017 Salesforce
# Copyright (c) 2009 37signals, LLC
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

require 'net/http'
require 'json'
require 'uri'

module Barnes
  class Reporter
    MAX_RETRIES = 3
    HTTP_TIMEOUT = 5

    ServerError = Class.new(StandardError)

    def initialize(url:)
      @uri = URI.parse(url)
    end

    def report(env)
      counters = {}
      env[Barnes::COUNTERS].each { |k, v| counters["Rack.Server.All.#{k}"] = v }

      gauges = {}
      env[Barnes::GAUGES].each { |k, v| gauges["Rack.Server.All.#{k}"] = v }

      count = counters.size + gauges.size
      return if count == 0

      body = JSON.generate(counters: counters, gauges: gauges)
      post(body, count)
    end

    private

    def post(body, count)
      retries = 0
      pause = 0.1
      timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

      begin
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.use_ssl = @uri.scheme == "https"
        http.open_timeout = HTTP_TIMEOUT
        http.read_timeout = HTTP_TIMEOUT
        http.write_timeout = HTTP_TIMEOUT

        request = Net::HTTP::Post.new(@uri)
        request["Content-Type"] = "application/json"
        request["Measurements-Count"] = count.to_s
        request["Measurements-Time"] = timestamp
        request.body = body

        response = http.request(request)

        case response.code.to_i
        when 200..299
          # success
        when 400..499
          $stderr.puts "barnes: metrics POST rejected (#{response.code}): #{response.body}"
        when 500..599
          raise ServerError, "server error #{response.code}"
        end
      rescue ServerError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
             Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
             SocketError, IOError => e
        if retries < MAX_RETRIES
          retries += 1
          sleep pause
          pause *= 2
          retry
        else
          $stderr.puts "barnes: failed to POST metrics after #{MAX_RETRIES} retries: #{e.class}: #{e.message}"
        end
      rescue => e
        $stderr.puts "barnes: unexpected error posting metrics: #{e.class}: #{e.message}"
      end
    end
  end
end
