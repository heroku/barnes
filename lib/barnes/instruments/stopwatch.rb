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

module Barnes
  module Instruments
    class Stopwatch
      def initialize(timepiece = Timepiece)
        @timepiece = timepiece
      end

      def start!(state)
        state[:stopwatch] = current
      end

      def instrument!(state, counters, gauges)
        last = state[:stopwatch]
        wall_elapsed = @timepiece.wall - last[:wall]
        cpu_elapsed = @timepiece.cpu - last[:cpu]
        idle_elapsed = wall_elapsed - cpu_elapsed

        counters[:'Time.wall'] = wall_elapsed
        counters[:'Time.cpu']      = cpu_elapsed
        counters[:'Time.idle']     = idle_elapsed

        if wall_elapsed == 0
          counters[:'Time.pct.cpu']  = 0
          counters[:'Time.pct.idle'] = 0
        else
          counters[:'Time.pct.cpu']  = 100.0 * cpu_elapsed  / wall_elapsed
          counters[:'Time.pct.idle'] = 100.0 * idle_elapsed / wall_elapsed
        end

        state[:stopwatch] = current
      end

      private def current
        {
          :wall => @timepiece.wall,
          :cpu  => @timepiece.cpu,
        }
      end
    end

    module Timepiece
      def self.wall
        ::Time.now.to_f * 1000
      end

      def self.cpu
        Process.clock_gettime Process::CLOCK_PROCESS_CPUTIME_ID, :float_millisecond
      end
    end
  end
end
