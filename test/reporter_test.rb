require 'test_helper'
require 'barnes/reporter'
require 'json'
require 'socket'
require 'stringio'

class ReporterTest < Minitest::Test
  def setup
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @requests = []
    @response_status = "200 OK"
  end

  def teardown
    @server.close unless @server.closed?
  end

  def accept_one_request
    Thread.new do
      client = @server.accept
      request_line = client.gets
      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, value = line.strip.split(": ", 2)
        headers[key] = value
      end
      body = client.read(headers["Content-Length"].to_i)
      @requests << { request_line: request_line, headers: headers, body: body }
      client.print "HTTP/1.1 #{@response_status}\r\nContent-Length: 0\r\n\r\n"
      client.close
    end
  end

  def test_report_posts_json_with_correct_headers
    accept_one_request

    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")
    reporter.report(
      Barnes::COUNTERS => { :'GC.count' => 5 },
      Barnes::GAUGES   => { :'pool.capacity' => 40 }
    )

    sleep 0.1
    assert_equal 1, @requests.size
    req = @requests.first

    assert_equal "application/json", req[:headers]["Content-Type"]
    assert_equal "2", req[:headers]["Measurements-Count"]
    refute_nil req[:headers]["Measurements-Time"]

    body = JSON.parse(req[:body])
    assert_equal 5, body["counters"]["Rack.Server.All.GC.count"]
    assert_equal 40, body["gauges"]["Rack.Server.All.pool.capacity"]
  end

  def test_report_prefixes_metric_names
    accept_one_request

    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")
    reporter.report(
      Barnes::COUNTERS => { :'Time.wall' => 100.5 },
      Barnes::GAUGES   => { :'Objects.FREE' => 9999 }
    )

    sleep 0.1
    body = JSON.parse(@requests.first[:body])
    assert body["counters"].key?("Rack.Server.All.Time.wall")
    assert body["gauges"].key?("Rack.Server.All.Objects.FREE")
  end

  def test_report_skips_empty_metrics
    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")
    reporter.report(
      Barnes::COUNTERS => {},
      Barnes::GAUGES   => {}
    )

    sleep 0.1
    assert_equal 0, @requests.size
  end

  def test_report_retries_on_server_error
    @response_status = "500 Internal Server Error"
    threads = (1 + Barnes::Reporter::MAX_RETRIES).times.map { accept_one_request }

    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")

    _stderr = capture_stderr do
      reporter.report(
        Barnes::COUNTERS => { :'GC.count' => 1 },
        Barnes::GAUGES   => {}
      )
    end

    threads.each { |t| t.join(5) }
    assert_equal 1 + Barnes::Reporter::MAX_RETRIES, @requests.size
  end

  def test_report_does_not_retry_on_client_error
    @response_status = "422 Unprocessable Entity"
    accept_one_request

    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")

    capture_stderr do
      reporter.report(
        Barnes::COUNTERS => { :'GC.count' => 1 },
        Barnes::GAUGES   => {}
      )
    end

    sleep 0.1
    assert_equal 1, @requests.size
  end

  private

  def capture_stderr
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old_stderr
  end
end
