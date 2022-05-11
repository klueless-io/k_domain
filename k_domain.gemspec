# frozen_string_literal: true

require_relative 'lib/k_domain/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version  = '>= 2.7'
  spec.name                   = 'k_domain'
  spec.version                = KDomain::VERSION
  spec.authors                = ['David Cruwys']
  spec.email                  = ['david@ideasmen.com.au']

  spec.summary                = 'K Domain builds complex domain schemas by combining the database schema with a rich entity relationship DSLs'
  spec.description            = <<-TEXT
    K Domain builds complex domain schemas by combining the database schema with a rich entity relationship DSLs
  TEXT
  spec.homepage               = 'http://appydave.com/gems/k-domain'
  spec.license                = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.' unless spec.respond_to?(:metadata)

  # spec.metadata['allowed_push_host'] = "Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/klueless-io/k_domain'
  spec.metadata['changelog_uri'] = 'https://github.com/klueless-io/k_domain/commits/master'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the RubyGem files that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  # spec.extensions    = ['ext/k_domain/extconf.rb']

  spec.add_dependency 'activesupport'   , '~> 6'
  spec.add_dependency 'dry-struct', '~> 1'
  spec.add_dependency 'k_log' , '~> 0.0.0'
  spec.add_dependency 'peeky' , '~> 0.0.0'
end
