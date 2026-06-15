module Barnes
  module Instruments
    class RubyGC
      # Only the GC gauges that survive the MetaaS whitelist are emitted.
      # These are delta-computed (cur - last) so each sample is a standalone
      # per-interval value reported in `gauges`.
      GAUGE_COUNTERS = {
        :total_allocated_objects => :'GC.total_allocated_objects',
        :total_freed_objects => :'GC.total_freed_objects'
      }

      def start!(state)
        state[:ruby_gc] = GC.stat
      end

      def instrument!(state, gauges)
        last = state[:ruby_gc]
        cur = state[:ruby_gc] = GC.stat

        GAUGE_COUNTERS.each do |stat, metric|
          gauges[metric] = cur[stat] - last[stat] if cur.include? stat
        end

        gauges[:'GC.heap_free_slots'] = cur[:heap_free_slots] if cur.include?(:heap_free_slots)
      end
    end
  end
end
