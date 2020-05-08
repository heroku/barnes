require 'test_helper'
require 'barnes/instruments/puma_instrument'

class PumaStatsTest < Minitest::Test
  def stat_value(stats, key)
    ::Barnes::Instruments::PumaInstrument::StatValue.new(stats, key)
  end

  def test_key_single
    expected = rand(3..99)
    stat = stat_value({ pool_capacity: expected }, :pool_capacity)
    assert_equal expected, stat.value
  end

  def test_key_cluster
    expected = rand(3..99)
    stat = stat_value({ workers: 2, worker_status: [
      { last_status: { pool_capacity: expected } },
      { last_status: { pool_capacity: expected } }
    ] }, :pool_capacity)
    assert_equal expected + expected, stat.value
  end

  def test_cluster_no_values
    stats_hash = { workers: 0, phase: 0, booted_workers: 0, old_workers: 0, worker_status: [] }
    stat       = stat_value(stats_hash, "booted")
    assert_nil stat.value
  end

  def test_missing_key_single
    stats_hash = { backlog: 0, running: 0, pool_capacity: 16 }
    stat       = stat_value(stats_hash, :does_not_exist)
    assert_nil stat.value
  end

  def test_missing_key_cluster
    stats_hash = { workers: 2, worker_status: [{ last_status: {} }] }
    stat       = stat_value(stats_hash, :does_not_exist)
    assert_nil stat.value
  end

  def test_max_threads_single
    expected   = rand(3..99)
    stats_hash = { backlog: 0, running: 0, max_threads: expected }
    stat = stat_value(stats_hash, :max_threads)
    assert_equal expected, stat.value
  end

  def test_max_threads_cluster
    expected   = rand(3..99)
    stats_hash = {
      workers: 2, worker_status: [
        {last_status: { max_threads: expected }},
        {last_status: { max_threads: expected }}
      ]
    }
    stat = stat_value(stats_hash, :max_threads)
    assert_equal expected + expected, stat.value
  end
end
