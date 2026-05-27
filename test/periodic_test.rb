require 'test_helper'
require 'barnes/periodic'

class PeriodicTest < Minitest::Test
  def test_report_called_and_stop_works
    report_count = 0
    mutex = Mutex.new
    reporter = Object.new
    reporter.define_singleton_method(:report) { |_| mutex.synchronize { report_count += 1 } }

    periodic = Barnes::Periodic.new(reporter: reporter, interval: 0.1)
    while mutex.synchronize { report_count } < 1
      sleep 0.1
    end

    assert periodic.thread.alive?, "Expected thread to be alive"
    periodic.stop(wait: true)
    refute periodic.thread.alive?, "Expected thread to be stopped"
  ensure
    if periodic&.thread&.alive?
      periodic.thread.exit
      periodic.thread.join
    end
  end
end
