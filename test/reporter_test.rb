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
    @mutex = Mutex.new
    @request_recorded = ConditionVariable.new
    @response_status = "200 OK"
  end

  def teardown
    @server.close unless @server.closed?
  end

  def accept_one_request(status: nil)
    Thread.new do
      client = @server.accept
      request_line = client.gets
      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, value = line.strip.split(": ", 2)
        headers[key] = value
      end
      body = client.read(headers["Content-Length"].to_i)
      @mutex.synchronize do
        @requests << { request_line: request_line, headers: headers, body: body }
        @request_recorded.broadcast
      end
      resp = status || @response_status
      client.print "HTTP/1.1 #{resp}\r\nContent-Length: 0\r\n\r\n"
      client.close
    end
  end

  def wait_for_requests(n, timeout: 5)
    deadline = Time.now + timeout
    @mutex.synchronize do
      while @requests.size < n
        remaining = deadline - Time.now
        raise "Timed out waiting for #{n} request(s) (got #{@requests.size})" if remaining <= 0
        @request_recorded.wait(@mutex, remaining)
      end
    end
  end

  def test_report_posts_json_with_correct_headers
    accept_one_request

    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")
    reporter.report(
      Barnes::GAUGES => { :'pool.capacity' => 40, :'GC.heap_free_slots' => 5 }
    )

    wait_for_requests(1)
    req = @requests.first

    assert_equal "application/json", req[:headers]["Content-Type"]
    assert_equal "2", req[:headers]["Measurements-Count"]
    refute_nil req[:headers]["Measurements-Time"]

    body = JSON.parse(req[:body])
    refute body.key?("counters"), body.inspect
    assert_equal 40, body["gauges"]["Rack.Server.All.pool.capacity"]
    assert_equal 5, body["gauges"]["Rack.Server.All.GC.heap_free_slots"]
  end

  def test_report_prefixes_metric_names
    accept_one_request

    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")
    reporter.report(
      Barnes::GAUGES => { :'threads.max' => 5 }
    )

    wait_for_requests(1)
    body = JSON.parse(@requests.first[:body])
    assert body["gauges"].key?("Rack.Server.All.threads.max")
  end

  def test_report_skips_empty_metrics
    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")
    reporter.report(
      Barnes::GAUGES => {}
    )

    assert_equal 0, @requests.size
  end

  def test_report_retries_on_server_error
    @response_status = "500 Internal Server Error"
    expected_count = 1 + Barnes::Reporter::MAX_RETRIES
    expected_count.times { accept_one_request }

    reporter = Barnes::Reporter.new(
      url: "http://127.0.0.1:#{@port}/metrics",
      backoff_sleep: ->(_) {}
    )

    _stderr = capture_stderr do
      reporter.report(
        Barnes::GAUGES => { :'GC.heap_free_slots' => 1 }
      )
    end

    wait_for_requests(expected_count)
    assert_equal expected_count, @requests.size
  end

  def test_report_retries_then_succeeds
    statuses = Queue.new
    statuses << "500 Internal Server Error"
    statuses << "500 Internal Server Error"
    statuses << "200 OK"

    accept_thread = Thread.new do
      until statuses.empty?
        client = @server.accept
        request_line = client.gets
        headers = {}
        while (line = client.gets) && line != "\r\n"
          key, value = line.strip.split(": ", 2)
          headers[key] = value
        end
        body = client.read(headers["Content-Length"].to_i)
        @mutex.synchronize do
          @requests << { request_line: request_line, headers: headers, body: body }
          @request_recorded.broadcast
        end
        client.print "HTTP/1.1 #{statuses.pop(true)}\r\nContent-Length: 0\r\n\r\n"
        client.close
      end
    end

    reporter = Barnes::Reporter.new(
      url: "http://127.0.0.1:#{@port}/metrics",
      backoff_sleep: ->(_) {}
    )

    stderr = capture_stderr do
      reporter.report(
        Barnes::GAUGES => { :'GC.heap_free_slots' => 1 }
      )
    end

    accept_thread.join(5)
    wait_for_requests(3)
    assert_equal 3, @requests.size
    assert_empty stderr
  end

  def test_report_does_not_retry_on_client_error
    @response_status = "422 Unprocessable Entity"
    accept_one_request

    reporter = Barnes::Reporter.new(url: "http://127.0.0.1:#{@port}/metrics")

    capture_stderr do
      reporter.report(
        Barnes::GAUGES => { :'GC.heap_free_slots' => 1 }
      )
    end

    wait_for_requests(1)
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
