# frozen_string_literal: true

source "https://rubygems.org"

# Production image uses Ruby 4.0.4 (see Dockerfile). Local Ruby 3.3+ is supported for dev.
gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"

gem "bcrypt", "~> 3.1.7"

gem "tzinfo-data", platforms: %i[windows jruby]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

group :development do
  gem "web-console"
end
