require 'test_helper'

class IntegrationTest < Minitest::Test
  def test_puma
    Dir.chdir(fixture_path("rack/hello_world")) do |dir|
      WaitForIt.new("bundle exec puma", options) do |spawn|
        spawn.wait('"barnes.gauges":', 1)
        expect_spawn_to_contain(spawn, '"threads.spawned":0')
        expect_spawn_to_contain(spawn, '"using.puma":1')
      end
    end
  end

  def test_no_puma
    Dir.chdir(fixture_path("rack/no_puma")) do |dir|
      WaitForIt.new("bundle exec rackup", options) do |spawn|
        spawn.wait('"barnes.gauges":', 1)
        spawn_should_not_contain(spawn, '"using.puma":1')
      end
    end
  end

  def test_workers_before_fork
    Dir.chdir(fixture_path("rack/workers")) do |dir|
      WaitForIt.new("bundle exec puma -C ./config.rb",
        options(INSERT_BARNES_BEFORE_FORK: "true")) do |spawn|
        # must wait past Puma::Cluster::WORKER_CHECK_INTERVAL
        spawn.wait(%Q{"pool.capacity":10}, 7)
        expect_spawn_to_contain(spawn, %Q{"pool.capacity":10})
        expect_spawn_to_contain(spawn, %Q{"using.puma":1})
      end
    end
  end

  def test_double_start_stops_previous
    Dir.chdir(fixture_path("rack/workers")) do |dir|
      WaitForIt.new("bundle exec puma -C ./config.rb",
        options(DOUBLE_BARNES_BEFORE_FORK: "true")) do |spawn|
        spawn.wait("Restarting Barnes", 7)
        expect_spawn_to_contain(spawn, "Restarting Barnes")
      end
    end
  end

  def test_workers_on_boot
    Dir.chdir(fixture_path("rack/workers")) do |dir|
      WaitForIt.new("bundle exec puma -C ./config.rb",
        options(INSERT_BARNES_ON_WORKER_BOOT: "true")) do |spawn|
        # must wait past Puma::Cluster::WORKER_CHECK_INTERVAL
        sleep 7
        spawn_should_not_contain(spawn, %Q{"pool.capacity":10})
        expect_spawn_to_contain(spawn, %Q{"using.puma":1})
      end
    end
  end

  def options(env = nil)
    port    = next_open_port
    options = {}
    options[:env] = {
      "DYNO"              => "web.1",
      "PORT"              => port,
      "HEROKU_METRICS_URL" => "http://127.0.0.1:#{port}/metrics",
      "BARNES_DEBUG"      => "1"
    }
    options[:env].merge!(env) if env
    options[:wait_for] = "Use Ctrl-C to stop"
    options
  end

  def spawn_should_not_contain(spawn, string)
    expect_spawn_to_contain(spawn, string, does_contain: false)
  end

  def expect_spawn_to_contain(spawn, string, does_contain: true)
    assert_equal does_contain, !!spawn.contains?(string), "Expected: \n#{spawn.log.read}\nto contain #{string.inspect} but it did not:"
  end
end
