---
name: solid-queue-setup
description: >-
  Solid Queue, the Rails 8 Active Job backend — `config/queue.yml`, the `bin/jobs`
  supervisor with its worker and dispatcher processes, the Puma plugin, concurrency
  limits, recurring schedules, failed jobs and retries, and the move from Sidekiq.
when_to_use: >-
  Use when the user configures Solid Queue or a worker process, asks why a background
  job is not running or not retrying, wants a concurrency limit or a recurring
  schedule, inspects a failed job or a queue backlog, writes a job spec, reaches for
  Mission Control, or moves from Sidekiq. For real-time WebSocket work, use Action Cable instead.
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/solid-queue-setup/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against: solid_queue 1.6.0, Rails 8.1.3.1, Ruby 3.4.5, rspec-rails 8.0.4, mission_control-jobs 1.1.0
---

# Solid Queue Setup for Rails 8

Solid Queue is the Active Job backend Rails 8 generates by default: database-backed, priorities
and multiple queues, and concurrency limits that Active Job on its own does not have.

File names and commands below hold for solid_queue 1.6.0 on Rails 8.1.

## Start from what the app already has

A Rails 8.1 app generated without `--skip-solid` already has the gem **and** has already run the
installer. Read the app before changing anything:

```bash
rg -n 'solid_queue' Gemfile
ls config/queue.yml config/recurring.yml bin/jobs db/queue_schema.rb
rg -n 'solid_queue|queue_adapter' config/environments/production.rb
```

Run `bin/rails solid_queue:install` when that `ls` reports any of the four missing. It creates
them, and it also edits
**`config/environments/production.rb` only**, writing both the adapter and the database connection:

```ruby
# config/environments/production.rb — written by the installer
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

Keep the adapter line in an environment file. `config/application.rb` applies to every environment,
where `connects_to` and the `queue:` database entry are absent, so `perform_later` there raises
`PG::UndefinedTable`, and in test it displaces the Active Job test adapter that `have_enqueued_job`
depends on.

## Creating the tables

`db/queue_schema.rb` is a schema dump, and `bin/rails db:prepare` is what loads it. `db:prepare`
and `db:migrate` both initialize every database configured for the current environment from its
schema dump when that database has no `schema_migrations` table yet
(`activerecord/lib/active_record/tasks/database_tasks.rb:174-182,241-243,651-665`).

The generated `config/database.yml` configures the `queue:` database **only under `production:`**,
so in development and test there is no `queue:` entry and therefore no Solid Queue tables, whichever
task you run. That is a configuration fact, not a bug to fix.

## Development runs on `:async`, test on the test adapter

Since the installer touches `production.rb` only, every other environment keeps Active Job's own
default: `activejob/lib/active_job/railtie.rb:47` sets `queue_adapter ||= Rails.env.test? ? :test :
:async`. So development runs on `:async` and test on the test adapter. In development
`perform_later` runs the job on an in-process thread pool, writes no `solid_queue_jobs` row, and
loses queued work on restart.

**This is the answer to "my job ran but nothing appears in Solid Queue" and to "`bin/jobs` polls
forever and processes nothing."** Confirm it in one line before investigating anything else:

```bash
bin/rails runner 'puts ActiveJob::Base.queue_adapter_name'   # => "async" on a stock app
```

`:async` is a fine default for development. To process jobs through Solid Queue there instead, give
development its own queue database and point the adapter at it:

```yaml
# config/database.yml
development:
  primary:
    <<: *default
    database: myapp_development
  queue:
    <<: *default
    database: myapp_development_queue
    migrations_paths: db/queue_migrate
```

```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

Then `bin/rails db:prepare` creates `myapp_development_queue` and loads `db/queue_schema.rb` into it.

## Running the supervisor

```bash
bin/jobs                      # supervisor: dispatchers + workers, from config/queue.yml
bin/rails solid_queue:check   # validate the configuration without starting any process
```

`bin/jobs` is the executable binstub the installer writes. Two other ways to run the same supervisor:

- **Inside Puma.** Rails 8.1 generates `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` in
  `config/puma.rb`, so setting that variable runs the supervisor in the web process — one container,
  which is what a small Kamal deploy wants.
- **As its own Kamal role**, with `bin/jobs` as the command, when jobs need to scale separately from
  web.

## config/queue.yml

The installer writes this, and it is the file the supervisor reads
(`SolidQueue::Configuration::DEFAULT_CONFIG_FILE_PATH`):

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 1

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

Keep every environment key, including `test:`. With an environment missing, the supervisor falls
back to its hardcoded defaults rather than to this file's `default:` anchor. That fallback is
silent, so the file reads as if it were being honoured.

A worker is one process with a thread pool that claims and performs jobs; a dispatcher polls for
scheduled jobs that are due and moves them to ready. To split work by queue in production, give
each set of queues its own worker entry:

```yaml
production:
  <<: *default
  workers:
    - queues: [ critical, default ]
      threads: 5
      processes: 2
    - queues: [ low ]
      threads: 2
      processes: 1
```

## Creating jobs

### Basic job

```ruby
# app/jobs/send_welcome_email_job.rb
class SendWelcomeEmailJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_later
  end
end
```

### Retries, discards, and error reporting

```ruby
# app/jobs/process_payment_job.rb
class ProcessPaymentJob < ApplicationJob
  queue_as :critical

  # report: true sends the error to Rails.error on every attempt, then retries.
  retry_on PaymentGatewayError, wait: :polynomially_longer, attempts: 5, report: true

  # The order is gone, so there is nothing to retry.
  discard_on ActiveRecord::RecordNotFound, report: true

  # Runs once the job is finally given up on, whether by discard or by exhausted retries.
  after_discard do |job, error|
    ErrorNotifier.notify(error, job_id: job.job_id)
  end

  def perform(order_id)
    order = Order.find(order_id)
    PaymentService.new.charge(order)
  end
end
```

`attempts: 5` counts the first execution, so it means four retries. `wait: :polynomially_longer`
waits about 3s, 18s, 83s, and so on.

**Report errors through `retry_on`, `discard_on` and `after_discard`, as above, and the retry and
discard behaviour survives.** `retry_on` and `discard_on` are themselves `rescue_from` handlers, and
Active Job documents that they are "searched from bottom to top" — `ActiveSupport::Rescuable`
searches `rescue_handlers.reverse_each` — so whichever handler is declared last is the one that runs.
A `rescue_from(StandardError)` block declared below them therefore matches first and they never run.
Re-raising from inside it does not reach them either: the exception escapes `perform_now`, and the
job goes straight to `solid_queue_failed_executions`.

Verified live on solid_queue 1.6.0 by enqueueing one job of each shape and running `bin/jobs`: the
version with a trailing `rescue_from(StandardError)` produced **1 failed execution and 0 retries**,
while the version above finished the attempt and left **1 scheduled execution due 5 seconds later**.

### Concurrency limits

Solid Queue's own addition to Active Job, and the reason to reach for it over `:async`:

```ruby
class ImportFeedJob < ApplicationJob
  # At most one import per account at a time; later ones wait.
  limits_concurrency key: ->(account) { account }, to: 1, duration: 5.minutes

  def perform(account)
    FeedImporter.new(account).run
  end
end
```

- `key:` is required, and takes a symbol, a string, or a proc over the job arguments. A proc
  returning an Active Record record keys on its class name and id.
- `to:` defaults to `1`.
- `duration:` defaults to `SolidQueue.default_concurrency_control_period` (3 minutes) and acts as the
  failsafe that releases the semaphore if a worker dies holding it.
- `group:` defaults to the job class name; share one across classes to limit them together.
- `on_conflict:` is `:block` by default — extra jobs land in `solid_queue_blocked_executions` and are
  released as earlier ones finish. `on_conflict: :discard` drops them at enqueue instead.

Measured on 1.6.0: three `perform_later` calls with the same key gave **1 ready and 2 blocked**
under `:block`, and **1 job row total** under `:discard`.

### Priority

```ruby
class UrgentNotificationJob < ApplicationJob
  queue_as :critical

  # Lower number = higher priority. Default is 0.
  queue_with_priority(-10)

  def perform(notification_id)
    # ...
  end
end
```

`queue_with_priority` sets the default that `set(priority: …)` at the call site can still override.
Defining `def priority` instead overrides Active Job's priority *reader*, which discards both the
call-site value and the priority restored during `deserialize`.

## Enqueueing jobs

```ruby
# Enqueue immediately
SendWelcomeEmailJob.perform_later(user.id)

# Enqueue with delay
SendReminderJob.set(wait: 1.hour).perform_later(user.id)

# Enqueue at a specific time
SendReportJob.set(wait_until: Date.tomorrow.noon).perform_later

# Enqueue on a specific queue
ProcessJob.set(queue: :low).perform_later(data)

# Run inline in the calling process, for a rake task or a console session
SendWelcomeEmailJob.perform_now(user.id)
```

## Recurring jobs

`config/recurring.yml`, also written by the installer. Keys are scoped by environment, and the
schedule strings are parsed by `fugit`, so both natural language and cron syntax work:

```yaml
production:
  daily_report:
    class: GenerateDailyReportJob
    schedule: every day at 6am
    queue: low

  cleanup:
    class: CleanupOldRecordsJob
    schedule: every sunday at 2am

  sync:
    class: SyncExternalDataJob
    schedule: every 15 minutes
```

A task can also run a `command:` string instead of naming a job class. The installed template
already uses that form to schedule the finished-job cleanup hourly:

```yaml
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
```

`clear_finished_in_batches` takes `batch_size:` (500), `finished_before:`
(`SolidQueue.clear_finished_jobs_after.ago`, a day), `class_name:` and `sleep_between_batches:`, and
deletes in bounded batches — which is what keeps a high-throughput jobs table from accumulating dead
tuples behind one long transaction. Reach for it, and for `SolidQueue.clear_finished_jobs_after`,
rather than writing a cleanup job.

## Testing jobs

### Job spec

```ruby
# spec/jobs/send_welcome_email_job_spec.rb
require 'rails_helper'

RSpec.describe SendWelcomeEmailJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    it 'enqueues the welcome email' do
      expect {
        described_class.perform_now(user.id)
      }.to have_enqueued_mail(UserMailer, :welcome)
    end
  end

  describe 'enqueueing' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(user.id)
      }.to have_enqueued_job(described_class)
        .with(user.id)
        .on_queue('default')
    end
  end
end
```

`have_enqueued_mail` matches an enqueued `MailDeliveryJob`, so it holds for a job whose `perform`
calls `deliver_later`. When the job calls `deliver_now`, assert on the delivery instead:
`expect { … }.to change { ActionMailer::Base.deliveries.size }.by(1)`.

Assert retry behaviour through the reschedule it causes, since the retry is a real enqueue:

```ruby
# spec/jobs/process_payment_job_spec.rb
RSpec.describe ProcessPaymentJob, type: :job do
  let(:order) { create(:order) }

  it 'reschedules itself when the gateway fails' do
    allow(PaymentService).to receive(:new).and_raise(PaymentGatewayError)

    expect { described_class.perform_now(order.id) }
      .to have_enqueued_job(described_class)
  end
end
```

### Test helpers

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :job
end
```

Scope it to `type: :job`. rspec-rails 8's job group is `RailsExampleGroup` and does not include the
helper, so adding it is what makes `perform_enqueued_jobs` and the enqueued-job accessors available.
Scoping it keeps its Minitest `before_setup`/`after_teardown` lifecycle — which is what installs and
clears the test adapter's queues — on the groups that run that lifecycle.

```ruby
it 'processes all jobs' do
  perform_enqueued_jobs do
    UserSignupService.call(user_params)
  end
  expect(user.reload.welcome_email_sent?).to be true
end

it 'enqueues multiple jobs' do
  expect {
    BatchProcessor.process(items)
  }.to have_enqueued_job(ProcessItemJob).exactly(items.count).times
end
```

## Inspecting the queues

```ruby
# Backlog: jobs claimable right now
SolidQueue::ReadyExecution.count

# Due later
SolidQueue::ScheduledExecution.count

# Blocked behind a concurrency limit
SolidQueue::BlockedExecution.count

# Failures, and the error each one recorded
SolidQueue::FailedExecution.count
SolidQueue::FailedExecution.includes(:job).map { |f| [ f.job.class_name, f.error["exception_class"] ] }

# Retry one, or all of a class
SolidQueue::FailedExecution.last.retry
```

Read the execution tables for state, not `SolidQueue::Job`. `finished_at` is set on success only, so
`SolidQueue::Job.where(finished_at: nil).count` also counts failed rows, blocked rows, scheduled
rows, and jobs executing right now — measured at 2 on a queue whose real ready backlog was 0.

## Mission Control

A web UI for queues, failures and retries. It is a separate gem rather than a Rails 8.1 default, so
check the Gemfile first and let the user decide about adding it:

```bash
rg -n 'mission_control-jobs' Gemfile
```

When it is present, mount the engine:

```ruby
# config/routes.rb
mount MissionControl::Jobs::Engine, at: "/jobs"
```

At 1.1.0 the engine is protected out of the box: `http_basic_auth_enabled` defaults to `true` and
the UI stays closed until credentials exist, so a fresh mount answers **401** — verified by
requesting `/jobs` on a mounted engine with no credentials set. Configure them under a
`mission_control:` key in Rails credentials, or run
`bin/rails mission_control:jobs:authentication:configure`.

To put it behind the app's own admin session instead, point the engine at a controller that already
authenticates, and turn Basic auth off:

```ruby
# config/application.rb
config.mission_control.jobs.base_controller_class = "Admin::BaseController"
config.mission_control.jobs.http_basic_auth_enabled = false
```

Since the UI can retry and discard jobs, keep one of the two mechanisms in place.

## Migration from Sidekiq

| Sidekiq | Solid Queue |
|---------|-------------|
| `perform_async(args)` | `perform_later(args)` |
| `perform_in(5.minutes, args)` | `set(wait: 5.minutes).perform_later(args)` |
| `sidekiq_options queue: 'critical'` | `queue_as :critical` |
| `sidekiq_retry_in` | `retry_on` with `wait:` |
| `sidekiq_options lock: …` (Enterprise) | `limits_concurrency key:, to:` |
| `bundle exec sidekiq` | `bin/jobs` |
| Redis | the `queue:` database in `config/database.yml` |
