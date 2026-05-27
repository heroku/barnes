workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

if ENV["INSERT_BARNES_BEFORE_FORK"]
  before_fork do
    require 'barnes'
    Barnes.start(interval: 1)
  end
end

if ENV["DOUBLE_BARNES_BEFORE_FORK"]
  before_fork do
    require 'barnes'
    Barnes.start(interval: 1)
    Barnes.start(interval: 1)
  end
end

if ENV["INSERT_BARNES_ON_WORKER_BOOT"]
  on_worker_boot do
    require 'barnes'
    Barnes.start(interval: 1)
  end
end
