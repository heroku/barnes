module Barnes
  module Instruments
    class RubyGC
      # Both sets are delta-computed (cur - last), but they land in
      # different reporting buckets.  COUNTERS go to `counters` (accumulated
      # totals the receiver can sum).  GAUGE_COUNTERS go to `gauges` so each
      # sample is a standalone per-interval value.  Keeping them separate also
      # excludes them from the raw-value gauge loop below.
      COUNTERS = {
        :count => :'GC.count',
        :major_gc_count => :'GC.major_count',
        :minor_gc_count => :'GC.minor_gc_count' }

      GAUGE_COUNTERS = {
        :total_allocated_objects => :'GC.total_allocated_objects',
        :total_freed_objects => :'GC.total_freed_objects'
      }

      def start!(state)
        state[:ruby_gc] = GC.stat
      end

      def instrument!(state, counters, gauges)
        last = state[:ruby_gc]
        cur = state[:ruby_gc] = GC.stat

        COUNTERS.each do |stat, metric|
          counters[metric] = cur[stat] - last[stat] if cur.include? stat
        end

        GAUGE_COUNTERS.each do |stat, metric|
          gauges[metric] = cur[stat] - last[stat] if cur.include? stat
        end

        cur.each do |k, v|
          unless GAUGE_COUNTERS.include? k
            gauges[:"GC.#{k}"] = v
          end
        end
      end
    end
  end
end
