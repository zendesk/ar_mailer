# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{convoy}
  s.version = "1.5.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Eric Hodel", "Adam Meehan", "Morten Primdahl", "Eric Chapweske"]
  s.date = %q{2010-08-24}
  s.description = %q{A more extendable version of AR Mailer. Supports non-ActiveRecord queues and customizable delivery behavior.}
  s.email = %q{eac@zendesk.com}
  s.extra_rdoc_files = ["History.txt", "LICENSE.txt", "README.rdoc"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{A two-phase delivery agent for ActionMailer}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
