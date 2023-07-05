# JSON Schema

The following schemas were created using the following processes.

```
quicktype -o json-schema/database.json -t database -l schema spec/sample_output/printspeak/schema.json
quicktype -o json-schema/database.rb   -t database -l ruby   json-schema/database-altered.json
spec/sample_output/printspeak/schema.json
json-schema/database-altered.json
```

remove statistics
remove (or move rails structure)
drop erd_location

# K Domain

> K Domain builds complex domain schemas by combining the database schema with a rich entity relationship DSLs

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'k_domain'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install k_domain
```

## Stories

### Main Story

As an Application Developer, I need a rich and configurable ERD schema, so I can generate enterprise applications quickly

See all [stories](./STORIES.md)

## Usage

See all [usage examples](./USAGE.md)

### Basic Example

#### Basic example

Description for a basic example to be featured in the main README.MD file

```ruby
class SomeRuby; end
```

## Development

Checkout the repo

```bash
git clone klueless-io/k_domain
```

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

```bash
bin/console

Aaa::Bbb::Program.execute()
# => ""
```

`k_domain` is setup with Guard, run `guard`, this will watch development file changes and run tests automatically, if successful, it will then run rubocop for style quality.

To release a new version, update the version number in `version.rb`, build the gem and push the `.gem` file to [rubygems.org](https://rubygems.org).

```bash
rake publish
rake clean
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/klueless-io/k_domain. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License


The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the K Domain project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/klueless-io/k_domain/blob/master/CODE_OF_CONDUCT.md).

## Copyright

Copyright (c) David Cruwys. See [MIT License](LICENSE.txt) for further details.
