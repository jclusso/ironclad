# Ironclad

[![Gem Version](https://badge.fury.io/rb/ironclad.svg)](https://rubygems.org/gems/ironclad)
[![CI](https://github.com/jclusso/ironclad/actions/workflows/ci.yml/badge.svg)](https://github.com/jclusso/ironclad/actions/workflows/ci.yml)

Source your Rails credential keys from 1Password instead of committing them to
the repo or leaving them as plaintext files on disk.

Ironclad reads each environment's key (`master.key`, `production.key`) from
1Password and caches it in the local OS keystore — the macOS Keychain or the
Linux kernel keyring — so repeated use doesn't round-trip to 1Password. It
ships:

- a CLI for printing a key, editing credentials, and keeping `git diff`
  readable,
- a Railtie that loads the current environment's key into `ENV` at boot,
- Capistrano helpers so deploys need no key file, and
- an install generator that wires it all into a Rails app.

## How it works

`bin/ironclad <env>` is a read-through cache:

1. Look up the key in the OS keystore (`<app>-credentials-<env>`).
2. On a miss, read it from 1Password (`op read`) and seed the cache.

The cache never expires. After rotating a key, refresh it with
`bin/ironclad <env> --refresh`. Platforms with no supported keystore simply
fetch from 1Password every call.

## Requirements

- The [1Password CLI](https://developer.1password.com/docs/cli/) (`op`), signed
  in to the relevant account.
- macOS (`security`) or Linux (`keyctl`) for caching. Other platforms work but
  don't cache.

## Installation

Add it to your Gemfile:

```ruby
gem 'ironclad'
```

Then install and run the generator:

```sh
bundle install
bin/rails generate ironclad:install
```

The generator asks which environments you manage (so the config and the VS Code
dropdown match) and which optional integrations to set up (the VS Code "Edit
Credentials" task, Capistrano wiring). It writes `config/ironclad.yml` with a
`VAULT` placeholder reference per environment for you to fill in, plus a
`bin/ironclad` binstub.

## Configuration

`config/ironclad.yml` maps each environment to a 1Password secret reference. The
environment names are entirely up to you — `default` is the development/master
key, and you can define as many others as you like (`staging`, `production`,
`qa`, `review`, …):

```yaml
account: application-name
keys:
  default:    op://VAULT/application-name/master.key
  production: op://VAULT/application-name/production.key
```

- `account` — 1Password account shorthand passed to `op --account` (optional).
- `app` — OS keystore cache namespace (`<app>-credentials-<env>`). Optional;
  defaults to your Rails app name, so you normally omit it.
- `keys` — environment to 1Password reference. `default` is the development key;
  add an entry for any other environment you need.

## Usage

### CLI

```sh
bin/ironclad                      # print the development key
bin/ironclad production           # print the production key
bin/ironclad production --refresh # bypass the cache after a rotation
bin/ironclad edit staging         # edit staging credentials in your editor
```

### Capistrano

Require the helpers in your `Capfile`:

```ruby
require 'ironclad/capistrano'
```

This sets `RAILS_MASTER_KEY` for the current stage from 1Password and adds a
`credential(*keys)` helper for reading the stage's encrypted credentials during
a deploy — no `config/credentials/<env>.key` file required.

### CI

Set `RAILS_MASTER_KEY` from a secret in your CI environment rather than shipping
a key file. Ironclad's boot step is a no-op when the key is already present.

## Development

```sh
bin/setup              # install dependencies
bundle exec rake test  # run the tests
bundle exec rubocop    # lint
bin/console            # interactive prompt
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
