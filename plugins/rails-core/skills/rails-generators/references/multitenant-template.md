# Multi-Tenant Application Template (Worked Example)

A complete application template that turns a Rails 8.1 starter app into a SaaS-ready multi-tenant
platform: Organizations as tenants, role-based Memberships, email invitations, and tenant scoping via
[acts_as_tenant](https://github.com/ErwinM/acts_as_tenant).

**Every claim below was executed against Rails 8.1.3.1, Ruby 3.4.5, PostgreSQL 17.10 and
acts_as_tenant 1.0.1 in a throwaway app.** The template writes `Gemfile` lines, which is what an
application template is for — that is a different act from telling someone to add a gem to a shared
project.

## What acts_as_tenant does and does not guarantee

`acts_as_tenant` implements scoping as a `default_scope`, and stating that precisely is what makes the
rest of this document safe to follow:

- **`Model.all` is scoped to `ActsAsTenant.current_tenant`.** Measured: with tenant A set,
  `Project.all.to_sql` is `SELECT "projects".* FROM "projects" WHERE "projects"."organization_id" = 1`.
- **`Model.unscoped` removes the scope**, because that is what `unscoped` means. Measured: 1 row scoped,
  2 rows unscoped. Treat `unscoped` on a tenant-scoped model as a security-relevant edit.
- **With no tenant set the scope evaluates to `all`** — every tenant's rows. Measured:
  `Project.all` returned both tenants' projects with `ActsAsTenant.current_tenant` nil. **Set
  `require_tenant = true` so this raises instead** (below).
- **A row whose tenant column is NULL is invisible while any tenant is set**, since the scope is a plain
  equality. Measured: hidden. `acts_as_tenant` also adds a required `belongs_to`, so the model itself
  refuses to create one — `ActiveRecord::RecordInvalid: Validation failed: Organization must exist`. A
  genuinely public table should not declare `acts_as_tenant` at all.

## Table of Contents

- [What acts_as_tenant does and does not guarantee](#what-acts_as_tenant-does-and-does-not-guarantee)
- [Architecture](#architecture)
- [Close the two leaks first](#close-the-two-leaks-first)
- [Template Skeleton](#template-skeleton)
- [Tenant Model: Organization](#tenant-model-organization)
- [Membership: Roles and Invitations](#membership-roles-and-invitations)
- [Tenant Selection from the URL](#tenant-selection-from-the-url)
- [Scoping Models](#scoping-models)
- [Registration Flow](#registration-flow)
- [Background Jobs](#background-jobs)
- [Testing](#testing)
- [Sources](#sources)

## Architecture

```text
User ──< Membership >── Organization (the tenant)
              │
              └── role: admin | member | viewer
                  + invitation fields (token, email, expiry)

Tenant-scoped models:  acts_as_tenant(:organization)
Tenant selection:      URL (/organizations/:organization_slug/...) via set_current_tenant_through_filter
Tenantless requests:   require_tenant = true, with ActsAsTenant.without_tenant where it is intended
```

- **Organization is the tenant model, so it does not declare `acts_as_tenant`.** The gem's default tenant
  argument is `:account`, so a bare `acts_as_tenant` adds `belongs_to :account` to whatever declares it.
  Measured on Organization: `reflect_on_all_associations(:belongs_to)` became `[:account]` and
  `Organization.create!` raised `NameError: Missing model class Account for the Organization#account
  association`. Scoped **child** models declare `acts_as_tenant(:organization)` explicitly — passing the
  argument is required, because the default is `:account`.
- **Membership joins Users to Organizations** and carries the role; authorization reads roles from it.
- **Membership is deliberately not tenant-scoped**, because invitation lookup by token happens before the
  visitor has a tenant. That exemption is safe only with the controller rule in the next section.

## Close the two leaks first

Both were reproduced on the earlier version of this template, and both fixes were then verified to close
them.

### Leak 1 — a request with no tenant sees every tenant

`set_current_tenant(nil)` on any action whose URL carries no organization slug leaves the tenant unset,
and the `default_scope` then evaluates to `all`. Measured before: `Project.all` returned
`["A project", "B project"]` across two organizations. `ActsAsTenant.configuration.require_tenant`
defaults to `false`, which is what makes silence the default.

**Fix — turn the permissive default into a raise, and make every intentional exception explicit:**

```ruby
initializer 'acts_as_tenant.rb', <<~RUBY
  ActsAsTenant.configure do |config|
    # A tenant-scoped query with no tenant set raises rather than returning every tenant's rows.
    config.require_tenant = true
  end
RUBY
```

Measured after: `Project.all` with no tenant raised `ActsAsTenant::Errors::NoTenantSet`, while
`ActsAsTenant.without_tenant { Project.count }` still returned 2 — so deliberate cross-tenant work keeps
working and accidental cross-tenant work stops. Un-scoped models are unaffected: with
`require_tenant = true` and no tenant, `Organization.count` and
`Membership.find_by(invitation_token: …)` both ran normally, which is what the invitation flow needs.

Pages that legitimately have no tenant — sign-in, the organization picker — should either touch only
un-scoped models or wrap the query in `ActsAsTenant.without_tenant`.

### Leak 2 — Membership is exempt from scoping, so a nested id is unscoped

Membership carries no `acts_as_tenant`, so `Membership.find(params[:id])` inside a nested
`MembershipsController` ignores the tenant. The slug check in `set_current_organization` does not catch
it, because it only validates the slug. Measured before: acting as a member of organization A,
`Membership.find(<organization B membership id>)` returned organization B's membership.

**Fix — reach every nested record through the tenant, so the scope comes from the association:**

```ruby
create_file 'app/controllers/memberships_controller.rb', <<~'RUBY'
  class MembershipsController < ApplicationController
    before_action :require_admin, only: %i[update destroy]

    def index
      @memberships = current_organization.memberships.includes(:user)
    end

    def update
      membership = current_organization.memberships.find(params[:id])
      ...
    end

    def destroy
      current_organization.memberships.find(params[:id]).destroy!
      ...
    end

    private

    def require_admin
      head :forbidden unless Current.user.admin_of?(current_organization)
    end
  end
RUBY
```

Measured after: `current_organization.memberships.find(<organization B id>)` raised
`ActiveRecord::RecordNotFound`, and the organization's own membership still resolved. The same rule
applies to any model you exempt from `acts_as_tenant`: **exempt from the default scope means scoped by
the association instead**, never unscoped.

## Template Skeleton

```ruby
# multitenant_template.rb — apply with:
#   rails new myapp -m multitenant_template.rb
#   bin/rails app:template LOCATION=multitenant_template.rb

# `super +`, not a bare array: a bare `[__dir__]` replaces the generator's own source
# paths, and Kamal's inline installer then cannot find its templates under `rails new`.
def source_paths
  super + [__dir__]
end

# Idempotency guard — model file, migration and schema signals only, so it works in
# both invocation contexts. See application-templates.md.
def already_applied?
  return true if File.exist?('app/models/organization.rb')
  return true if Dir.glob('db/migrate/*_create_organizations.rb').any?
  return true if File.exist?('db/schema.rb') &&
                 File.read('db/schema.rb').include?('create_table "organizations"')

  false
end

if already_applied?
  raise Thor::Error, 'Multi-tenant template already applied. Reapply from a clean git state.'
end

say '📦 Adding gems...'
gem 'acts_as_tenant', comment: 'Row-level multi-tenancy (https://github.com/ErwinM/acts_as_tenant)'
gem_group :development do
  gem 'letter_opener', comment: 'Preview email in the browser'
end
gem_group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end
run 'bundle install'

say '🔐 Installing authentication (Rails 8.1 built-in)...'
generate 'authentication'
environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
            env: 'development'

say '🧪 Installing RSpec, since the template writes specs...'
generate 'rspec:install'

say '🏢 Creating tenant models...'
generate 'model', 'Organization', 'name:string:uniq', 'slug:string:uniq', 'description:text'
generate 'model', 'Membership', '--skip-migration'   # migration generated and patched below
generate 'model', 'Project', 'name:string', 'organization:references'

# ... model bodies, the memberships migration, controller filter, routes (sections below) ...

after_bundle do
  rails_command 'db:prepare'
  run 'bundle exec rspec'
end
say '✅ Multi-tenant setup complete!', :green
```

Four details in that skeleton are load-bearing. The whole thing was applied with
`rails new mtapp --database=postgresql -m multitenant_template.rb`, which exited 0 with every migration
run, a `Gemfile.lock`, a `master.key`, and an app that boots.

- **`raise Thor::Error`, not `exit 1`.** `apply_rails_template` rescues `Thor::Error`; `SystemExit` is
  unrescued and tears down `rails new` mid-build. Verified both ways under `rails new -m`.
- **`super + [__dir__]` in `source_paths`.** `Thor::Actions#source_paths` is the list every action
  searches, so returning a bare `[__dir__]` discards the generator's own roots. Measured on a default
  `rails new`: the Kamal installer, which runs after the template is applied, died with
  `Could not find "kamal-secrets.tt" in any of your source paths`.
- **`generate 'rspec:install'` before anything writes to `spec/`.** A `rails new` app is on Minitest, so
  `run 'bundle exec rspec'` and a `create_file 'spec/rails_helper.rb'` both fail on a template that never
  installed RSpec.
- **`after_bundle` for anything that needs the gems.** It runs under `bin/rails app:template` as well as
  `rails new -m` — verified: `app:template` printed the callback's output after `bundle install`. What is
  specific to `app:template` is that gems added at the top are not installed until something runs
  `bundle install`, which is why the explicit `run 'bundle install'` above stays.

## Tenant Model: Organization

```ruby
create_file 'app/models/organization.rb', <<~RUBY, force: true
  class Organization < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :slug, presence: true, uniqueness: true

    has_many :memberships, dependent: :destroy
    has_many :users, through: :memberships

    scope :ordered, -> { order(:name) }

    def to_param = slug
  end
RUBY
```

No `acts_as_tenant` here: Organization **is** the tenant. See the note under Architecture for what
happens when the tenant model declares it.

## Membership: Roles and Invitations

Membership carries both the role and the invitation lifecycle, and stays outside `acts_as_tenant` so an
invitation can be found by token before the visitor has a tenant. Leak 2 above is the rule that makes
that exemption safe.

```ruby
create_file 'app/models/membership.rb', force: true do
  <<~'RUBY'
    class Membership < ApplicationRecord
      ROLES = %w[admin member viewer].freeze

      belongs_to :organization
      belongs_to :user, optional: true
      belongs_to :invited_by, class_name: 'User', optional: true

      validates :role, presence: true, inclusion: { in: ROLES }
      validates :user_id, uniqueness: { scope: :organization_id }, if: :user_id?
      validates :invited_email, presence: true,
                uniqueness: { scope: :organization_id }, if: :pending_invitation?

      scope :active,  -> { where.not(user_id: nil) }
      scope :pending, -> { where(user_id: nil) }

      before_validation :generate_invitation_token, if: :pending_invitation?
      before_validation :set_invitation_expiry, if: :pending_invitation?

      def pending_invitation? = user_id.nil? && invited_email.present?
      def admin?  = role == 'admin'
      def member? = role == 'member'
      def viewer? = role == 'viewer'

      def invitation_expired?
        pending_invitation? && invitation_expires_at&.past?
      end

      def accept_invitation!(user)
        return false unless pending_invitation? && !invitation_expired?

        update!(user: user, invitation_token: nil,
                invited_email: nil, invitation_expires_at: nil)
      end

      private

      def generate_invitation_token
        self.invitation_token = SecureRandom.urlsafe_base64(32)
      end

      def set_invitation_expiry
        self.invitation_expires_at ||= 7.days.from_now
      end
    end
  RUBY
end
```

### Generate the memberships migration, then patch what generator syntax cannot say

Two generator behaviours make `generate 'model', 'Membership', 'user:references',
'invited_by:references'` produce a migration that aborts, which is why the skeleton passes
`--skip-migration`:

- **`invited_by:references` infers the wrong table.** The generator writes `foreign_key: true`, and
  `"invited_by".pluralize` is `"invited_bies"`. Measured: `db:migrate` aborted with
  `PG::UndefinedTable: ERROR: relation "invited_bies" does not exist`, cancelling that migration and
  every later one. A self-referential or aliased reference needs `foreign_key: { to_table: :users }`.
- **`user:references` emits `null: false`.** Measured. But `optional: true`, `pending_invitation?`, the
  `:pending` scope, the `:pending` factory trait and the partial index below all require `user_id` to be
  nullable — a pending invitation has no user yet.

Let the migration generator write the file, then patch those two columns and add the partial indexes.
That keeps the timestamp sequencing and the `ActiveRecord::Migration[8.1]` version line out of your
hands:

```ruby
generate 'migration', 'CreateMemberships',
         'organization:references', 'role:string',
         'invitation_token:string:uniq', 'invited_email:string',
         'invitation_expires_at:datetime'

memberships_migration = Dir.glob('db/migrate/*_create_memberships.rb').first

# The two columns generator attribute syntax cannot express: a nullable reference,
# and a self-referential reference whose table is not the pluralized column name.
inject_into_file memberships_migration,
                 after: "      t.references :organization, null: false, foreign_key: true\n" do
  <<-RUBY
      t.references :user, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
  RUBY
end

inject_into_file memberships_migration,
                 after: "    add_index :memberships, :invitation_token, unique: true\n" do
  <<-RUBY
    add_index :memberships, [ :organization_id, :user_id ],
              unique: true, where: 'user_id IS NOT NULL'
    add_index :memberships, [ :organization_id, :invited_email ],
              unique: true, where: 'user_id IS NULL'
  RUBY
end

gsub_file memberships_migration, /t\.string :role$/, 't.string :role, null: false'
```

Measured under `rails new -m`: this produces `ActiveRecord::Migration[8.1]` with all three indexes, and
`db:prepare` applies it to both the development and test databases. A pending invitation with `user_id`
and `invited_by_id` both nil then inserts successfully. The partial indexes let the same email hold
pending invitations in different organizations while preventing duplicates within one.

**Do not interpolate `ActiveRecord::Migration.current_version` into the template.** Active Record is not
loaded in the `rails new` process, so it raises the same `NameError` as a database check in the
idempotency guard — measured: `rails new` exited 1 mid-build. Letting the generator write the version
line avoids the question, and it also avoids the timestamp collisions that hand-built
`Time.now.strftime` filenames produce when a template creates several migrations in a row.

**Anchor the injections on the generator's exact output.** `inject_into_file` no-ops silently on a
non-match, so if you name the migration something the generator's `create_table` inference does not
recognise, you get a migration that creates nothing. Reading the generated file once while developing the
template is the cheap way to confirm the anchors.

Convenience methods on User:

```ruby
inject_into_file 'app/models/user.rb', after: "class User < ApplicationRecord\n" do
  <<-RUBY
  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :sent_invitations, class_name: 'Membership', foreign_key: 'invited_by_id'

  def admin_of?(organization)
    memberships.find_by(organization: organization)&.admin?
  end

  def member_of?(organization)
    memberships.exists?(organization: organization)
  end
  RUBY
end
```

The Rails 8.1 authentication generator's User already has `has_many :sessions` and an `email_address`
column, so `after: "class User < ApplicationRecord\n"` is a stable anchor and the association names above
do not collide.

## Tenant Selection from the URL

The tenant comes from the URL, so links are shareable and a user can be active in different organizations
in different tabs.

```ruby
inject_into_file 'app/controllers/application_controller.rb',
                 after: "class ApplicationController < ActionController::Base\n" do
  <<-RUBY
  set_current_tenant_through_filter
  before_action :set_current_organization

  private

  def set_current_organization
    slug = params[:organization_slug] || params[:organization_id]
    return if slug.blank?   # tenantless page; require_tenant makes any scoped query raise

    organization = Current.user&.organizations&.find_by(slug: slug)
    raise ActiveRecord::RecordNotFound if organization.nil?   # member-only access; renders 404

    set_current_tenant(organization)
  end

  def current_organization = ActsAsTenant.current_tenant
  helper_method :current_organization
  RUBY
end
```

Two decisions in that filter:

- **Return early on a tenantless page rather than calling `set_current_tenant(nil)`.** With
  `require_tenant = true`, an unset tenant makes a scoped query raise `ActsAsTenant::Errors::NoTenantSet`
  — a loud failure at the query that forgot its scope, instead of a silent cross-tenant read.
- **Look the organization up through `Current.user.organizations`, not `Organization.find_by`**, so
  membership itself is the access check: non-members get a 404, not a 403 that confirms the organization
  exists. `Current.user` is what the Rails 8.1 authentication generator provides.

Routes nest tenant-owned resources under the organization:

```ruby
route <<~RUBY
  resource :session
  resources :passwords, param: :token

  get 'invitations/:token/accept', to: 'memberships#accept', as: :accept_invitation

  resources :organizations, param: :slug do
    resources :memberships, except: %i[show new edit]
    resources :projects   # tenant-scoped resources nest here
  end

  root 'organizations#index'
RUBY
```

`resource :session` is singular and `resources :passwords, param: :token` is the pair
`rails generate authentication` writes; keep them as generated rather than reaching for `devise_for`,
which does not exist on this stack.

## Scoping Models

Every tenant-owned model declares the scope, passing the tenant name explicitly:

```ruby
class Project < ApplicationRecord
  acts_as_tenant(:organization)

  # Tenant-scoped uniqueness — plain `uniqueness: true` would collide across tenants
  validates_uniqueness_to_tenant :name
end
```

`validates_uniqueness_to_tenant :name` is the gem's own helper and expands to a uniqueness validation
scoped to the tenant column, which is the reason to adopt the gem rather than hand-roll
`uniqueness: { scope: :organization_id }`. Both work; the helper keeps the tenant column name in one
place.

Controllers then read tenant-scoped models directly, because the default scope is doing the work:

```ruby
class ProjectsController < ApplicationController
  def index
    @projects = Project.all      # scoped to current tenant automatically
  end

  def create
    @project = Project.new(project_params)  # organization_id assigned automatically
    ...
  end
end
```

That shorthand holds **only for models that declare `acts_as_tenant`**. Anything you exempt — Membership
here — goes through the tenant association instead, per Leak 2.

The template can offer this as a follow-up generator for new resources, or teams add the one line by
hand. Migrations for tenant-scoped tables make the foreign key mandatory:

```ruby
add_reference :projects, :organization, null: false, foreign_key: true
```

A table that genuinely holds public rows should not declare `acts_as_tenant` at all: the gem adds a
required `belongs_to`, so the model refuses to create an untenanted row
(`Validation failed: Organization must exist`, measured), and the equality-based default scope hides any
NULL-tenant row that reaches the table by other means (also measured).

## Registration Flow

New sign-ups either accept a pending invitation (token stashed in the session) or get a personal
organization created for them. The Rails 8.1 authentication generator ships no registrations controller,
so the template writes one:

```ruby
create_file 'app/controllers/registrations_controller.rb', <<~'RUBY'
  class RegistrationsController < ApplicationController
    allow_unauthenticated_access

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        start_new_session_for @user
        redirect_to after_sign_up_path_for(@user)
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def user_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end

    def after_sign_up_path_for(user)
      token = session.delete(:invitation_token)
      membership = token.present? && Membership.find_by(invitation_token: token)

      if membership && membership.accept_invitation!(user)
        organization_path(membership.organization)
      else
        organization_path(create_personal_organization(user))
      end
    end

    def create_personal_organization(user)
      Organization.create!(name: "#{user.email_address}'s Organization",
                           slug: unique_slug).tap do |org|
        org.memberships.create!(user: user, role: 'admin')
      end
    end

    def unique_slug
      10.times do
        candidate = SecureRandom.urlsafe_base64(12).downcase.gsub(/[^a-z0-9]/, '')
        return candidate unless Organization.exists?(slug: candidate)
      end
      raise 'could not allocate a unique organization slug'
    end
  end
RUBY
```

Three corrections worth carrying into any invitation flow:

- **Guard the token before looking it up.** `session.delete(:invitation_token)` returns `nil` when the key
  is absent, and `Membership.find_by(invitation_token: nil)` then matches an arbitrary **already
  accepted** membership from any tenant — measured: it returned membership id 1 from a different
  organization. Today `accept_invitation!` rejects it, so the leak is latent rather than live; the
  `token.present? &&` guard is what keeps it that way.
- **Do not derive a unique slug from `SecureRandom.hex(4)`.** That is 32 bits, ~4.3e9 values, against a
  unique index — collisions eventually raise inside a sign-up. `urlsafe_base64(12)` is 96 bits, and the
  retry loop turns the remaining chance into a retry rather than a 500.
- **`Organization` is not tenant-scoped**, so creating it needs no `ActsAsTenant.without_tenant` wrapper;
  the membership create inside the `tap` is likewise on an un-scoped model.

The invitation-acceptance endpoint (`memberships#accept`) finds the membership by token, accepts directly
for signed-in users, and stores the token in the session before redirecting guests to sign-up. Send
invitation emails from a mailer with `deliver_later`, and add `letter_opener` in development to preview
them.

## Background Jobs

`ActsAsTenant.current_tenant` is per-request; jobs must set it explicitly, and with
`require_tenant = true` a job that forgets raises instead of reading every tenant:

```ruby
class SyncProjectsJob < ApplicationJob
  def perform(organization)
    ActsAsTenant.with_tenant(organization) do
      Project.find_each(&:sync!)   # scoped to organization
    end
  end
end
```

Pass the organization (or its id) as a job argument — never rely on ambient tenant state surviving into
the job. For maintenance scripts that legitimately cross tenants, use
`ActsAsTenant.without_tenant { ... }`, which stays available under `require_tenant = true` (measured).

## Testing

Factories:

```ruby
FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:slug) { |n| "org-#{n}" }
  end

  factory :membership do
    organization
    user
    role { 'member' }

    trait :admin do
      role { 'admin' }
    end

    trait :pending do
      user { nil }
      sequence(:invited_email) { |n| "invited#{n}@example.com" }
    end

    trait :expired do
      pending
      invitation_expires_at { 1.hour.ago }
    end
  end
end
```

Set a test tenant **per example**, so it is created inside the example's transaction and rolled back with
it:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.around(:each) do |example|
    ActsAsTenant.test_tenant = FactoryBot.create(:organization)
    example.run
    ActsAsTenant.test_tenant = nil
  end
end
```

Use `around(:each)`, not `before(:suite)`. A record created in `before(:suite)` is outside every
per-example transaction, so it commits and survives the run; on the next run the `name` and `slug`
sequences restart at 1 and collide with the unique indexes, and `create!` raises. `ActsAsTenant.test_tenant`
is also what keeps `require_tenant = true` from failing model specs that never mention a tenant.

For sign-in, drive the generated session route rather than a Devise helper — `sign_in` and
`Devise::Test::IntegrationHelpers` do not exist on this stack:

```ruby
# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in_as(user, password: 'password')
    post session_path, params: { email_address: user.email_address, password: password }
  end
end

RSpec.configure { |c| c.include AuthenticationHelpers, type: :request }
```

The test that matters most — isolation actually holds:

```ruby
RSpec.describe 'tenant isolation', type: :request do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }
  let(:user)  { create(:user) }

  before { create(:membership, user: user, organization: org_a) }

  it "hides other tenants' records" do
    project_b = ActsAsTenant.with_tenant(org_b) { create(:project) }

    sign_in_as user
    get organization_projects_path(org_a)
    expect(response.body).not_to include(project_b.name)
  end

  it 'returns 404 for organizations the user does not belong to' do
    sign_in_as user
    get organization_projects_path(org_b)
    expect(response).to have_http_status(:not_found)
  end

  it 'refuses a membership id belonging to another organization' do
    other = create(:membership, organization: org_b)

    sign_in_as user
    delete organization_membership_path(org_a, other)
    expect(response).to have_http_status(:not_found)
    expect(other.reload).to be_present
  end

  it 'raises rather than reading every tenant when no tenant is set' do
    expect { ActsAsTenant.with_tenant(nil) { Project.count } }
      .to raise_error(ActsAsTenant::Errors::NoTenantSet)
  end
end
```

The last two examples are the regression tests for the two leaks. A multi-tenancy suite without them
passes just as happily when the scoping is gone.

Finish the template with `after_bundle { rails_command 'db:prepare'; run 'bundle exec rspec' }` so a
broken apply fails at apply time rather than at first boot — and only after `rspec:install` has run.

## Sources

- [acts_as_tenant README](https://github.com/ErwinM/acts_as_tenant)
- [Rails Application Templates — Ruby on Rails Guides](https://guides.rubyonrails.org/rails_application_templates.html)
