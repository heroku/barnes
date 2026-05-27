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
  DEFAULT_INTERVAL = 10
  DEFAULT_PANELS   = [].freeze
  @caller = nil
  @periodic = nil
  @mutex = Mutex.new

  # Starts the metrics reporting client.
  #
  # Collects Ruby runtime metrics (GC stats, ObjectSpace counts,
  # Puma pool stats) and POSTs them to HEROKU_METRICS_URL.
  #
  # Arguments:
  #
  #   - interval: How often, in seconds, to instrument and report.
  #   - panels: The instrumentation "panels" in use. See `resource_usage.rb` for
  #     an example panel, which is the default if none are provided.
  def self.start(interval: DEFAULT_INTERVAL, panels: DEFAULT_PANELS)
    return if ENV["DYNO"]&.start_with?("run.")

    url = ENV["HEROKU_METRICS_URL"]
    return unless url

    @mutex.synchronize do
      reporter = Barnes::Reporter.new(url: url)

      panels = panels.dup
      if panels.empty?
        panels << Barnes::ResourceUsage.new
      end

      if @periodic
        debug("Restarting Barnes. Previously started by caller:")
        debug(@caller.join("\n"))
        @periodic.stop(wait: false)
      end

      @caller = caller
      @periodic = Periodic.new(
        reporter: reporter,
        interval: interval,
        panels:   panels,
        debug:    ENV['BARNES_DEBUG']
      )
    end
  end

  def self.debug(message)
    if ENV["BARNES_DEBUG"]
      puts "Barnes: #{message}"
    end
  end
end

require 'barnes/reporter'
require 'barnes/resource_usage'
require 'barnes/periodic'
require 'barnes/railtie' if defined? ::Rails::Railtie
