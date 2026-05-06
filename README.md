## Barnes

Ruby runtime metrics for [Heroku Runtime Metrics](https://devcenter.heroku.com/articles/language-runtime-metrics-ruby). Collects GC stats, ObjectSpace counts, and Puma thread/pool metrics and POSTs them directly to `HEROKU_METRICS_URL`.

Originally a fork of [trashed](https://github.com/basecamp/trashed).

## Setup

### Rails

Add this to your Gemfile:

```
gem "barnes"
```

Then run:

```
$ bundle install
```

Barnes will start automatically via a Railtie when `HEROKU_METRICS_URL` is set in the environment (this is provided automatically on Heroku dynos).

### Non-Rails (Puma)

Add the gem to your Gemfile:

```
gem "barnes"
```

Then in your `puma.rb`:

```ruby
require 'barnes'

before_fork do
  Barnes.start
end
```

## How it works

Barnes starts a background thread that collects metrics at a configurable interval (default: 10 seconds) and POSTs them as JSON to the URL in `HEROKU_METRICS_URL`.

Barnes is a **silent no-op** when:

- `HEROKU_METRICS_URL` is not set (e.g. local development)
- The dyno is a one-off `run.*` dyno

No external dependencies or sidecar processes are required.

## Configuration

```ruby
Barnes.start(
  interval: 10,   # seconds between reports (default: 10)
  panels:   []    # custom instrumentation panels (default: built-in ResourceUsage)
)
```

## Requirements

- Ruby >= 3.1
