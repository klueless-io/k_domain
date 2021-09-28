# K Domain

> K Domain builds complex domain schemas by combining the database schema with a rich entity relationship DSLs

As an Application Developer, I need a rich and configurable ERD schema, so I can generate enterprise applications quickly

## Development radar

### Stories next on list

As a Developer, I can print any of the domain structures, so that I can visually my domain

- Hook up log.structure

As a Developer, I can customize domain configuration, so that I can have opinions about names and types

- Handle traits

As a Developer, I can read native rails model data, so that I can leverage existing rails applications for ERD modeling

- Use Meta Programming and re-implement ActiveRecord::Base

### Tasks next on list

Refactor / Simply

- Replace complex objects an with structs for ancillary data structures such as investigate

User acceptance testing

- Provide sample printers for each data structure to visually check data is loading
- Point raw_db_schema loader towards a complex ERD and check how it performs

## Stories and tasks

### Tasks - completed

Setup RubyGems and RubyDoc

- Build and deploy gem to [rubygems.org](https://rubygems.org/gems/k_domain)
- Attach documentation to [rubydoc.info](https://rubydoc.info/github/to-do-/k_domain/master)

Setup project management, requirement and SCRUM documents

- Setup readme file
- Setup user stories and tasks
- Setup a project backlog
- Setup an examples/usage document

Setup GitHub Action (test and lint)

- Setup Rspec action
- Setup RuboCop action

Setup new Ruby GEM

- Build out a standard GEM structure
- Add automated semantic versioning
- Add Rspec unit testing framework
- Add RuboCop linting
- Add Guard for automatic watch and test
- Add GitFlow support
- Add GitHub Repository
