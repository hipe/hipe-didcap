# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{hipe-didcap}
  s.version = "0.0.0pre"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Chip Malice"]
  s.date = %q{2010-02-10}
  s.description = %q{dynamic interval delta (screen) capture}
  s.summary = %q{makes *.png image screen captures at intervals}
  s.email = %q{chip.malice@gmail.com}
  s.executables = ["hipe-didcap"]
  s.files = [
    ".gitignore",
    "lib/hipe-didcap.rb",
    "bin/hipe-didcap"
  ]
  s.has_rdoc = false
  s.homepage = %q{http://github.com/hipe/hipe-didcap}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}

  s.add_development_dependency 'baretest'
  s.add_development_dependency 'fakefs'


  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<hipe-core>, [">= 0.0.3"])
    else
      s.add_dependency(%q<hipe-core>, [">= 0.0.3"])
    end
  else
    s.add_dependency(%q<hipe-core>, [">= 0.0.3"])
  end
end
