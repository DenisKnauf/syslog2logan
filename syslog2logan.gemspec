# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{syslog2logan}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Denis Knauf"]
  s.date = %q{2010-01-30}
  s.default_executable = %q{s2l.rb}
  s.description = %q{Syslog-Server which logs to Berkeley Databases (No SyslogDaemon)}
  s.email = %q{Denis.Knauf@gmail.com}
  s.executables = ["s2l.rb"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README"
  ]
  s.files = [
    "README",
     "VERSION",
     "bin/s2l.rb"
  ]
  s.homepage = %q{http://github.com/DenisKnauf/syslog2logan}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["bin"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Syslog-Server}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sbdb>, [">= 0"])
      s.add_runtime_dependency(%q<select>, [">= 0"])
    else
      s.add_dependency(%q<sbdb>, [">= 0"])
      s.add_dependency(%q<select>, [">= 0"])
    end
  else
    s.add_dependency(%q<sbdb>, [">= 0"])
    s.add_dependency(%q<select>, [">= 0"])
  end
end

