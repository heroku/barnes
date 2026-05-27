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

require 'barnes/consts'
require 'json'

module Barnes
  class Periodic
    def initialize(reporter:, interval: 10, debug: false, panels: [])
      @reporter = reporter
      @debug = debug
      @interval = interval
      @panels = panels
      @stopping = false

      @thread = Thread.new {
        Thread.current[:barnes_state] = {}

        @panels.each do |panel|
          panel.start! Thread.current[:barnes_state]
        end

        loop do
          begin
            sleep @interval
            break if @stopping

            env = {
              STATE    => Thread.current[:barnes_state],
              COUNTERS => {},
              GAUGES   => {}
            }

            @panels.each do |panel|
              panel.instrument! env[STATE], env[COUNTERS], env[GAUGES]
            end

            puts env.to_json if @debug
            @reporter.report env
          rescue => e
            $stderr.puts "barnes: error during metrics collection: #{e.class}: #{e.message}"
          end
        end
      }
      @thread.abort_on_exception = true
    end

    def stop(wait: )
      @stopping = true
      @thread.wakeup if @thread.alive?
      @thread.join if wait
    end
  end
end
