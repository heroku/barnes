require 'test_helper'
require 'barnes/resource_usage'

class ResourceUsageTest < Minitest::Test
  def setup
    super
    @state = {}
    @panel = Barnes::ResourceUsage.new
    @panel.start! @state
  end

  def test_emits_whitelisted_gc_gauges
    gauges = gauges_from_instrument
    assert gauges.include?(:'GC.heap_free_slots'), gauges.inspect
    assert gauges.include?(:'GC.total_allocated_objects'), gauges.inspect
    assert gauges.include?(:'GC.total_freed_objects'), gauges.inspect
  end

  def test_does_not_emit_non_whitelisted_gc_gauges
    gauges = gauges_from_instrument
    refute gauges.include?(:'GC.heap_live_slots'), gauges.inspect
    refute gauges.include?(:'GC.count'), gauges.inspect
  end

  private def gauges_from_instrument
    gauges = {}
    @panel.instrument!(@state, gauges)
    gauges
  end
end
