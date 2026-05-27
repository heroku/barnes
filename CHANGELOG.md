## HEAD (unreleased)

## 1.0.1

- Fix: Previously calling `Barnes.start` would result in duplicate reporting threads. Now when this method is called, old threads are stopped before a new thread is started.

## 1.0.0

- **Breaking**: Replace StatsD with direct HTTP reporting to HEROKU_METRICS_URL
- **Breaking**: Remove `statsd:` and `aggregation_period:` parameters from `Barnes.start`
- **Breaking**: Require Ruby >= 3.1
- Remove `statsd-ruby` runtime dependency (zero runtime deps)
- Remove `sample_rate` scaling from instruments
- Barnes is a no-op when `HEROKU_METRICS_URL` is not set

## 0.1.0

- Add GitHub Actions to test against multiple Ruby versions
- remove MultiJSON in favor of built-in JSON

## 0.0.9

- Handle half-initialize Puma failure on boot (https://github.com/heroku/barnes/pull/37)

## 0.0.8

- Fix warnings in Ruby 2.7

## 0.0.7

- Report when an app is using Puma

## 0.0.6

- Support Puma max threads, support Puma spawned threads
- Drop Puma backlog metric

## 0.0.5

- Support Puma pool capacity value #15

## 0.0.4

- Support Puma backlog #14

## 0.0.3

## 0.0.2

- Fix requires for non-rails apps (#11)

## 0.0.1

- Fork and Release
