# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "postmark/version"

Gem::Specification.new do |s|
  s.name             = "postmark"
  s.version          = Postmark::VERSION
  s.homepage         = "http://postmarkapp.com"
  s.platform         = Gem::Platform::RUBY
  s.license          = 'MIT'

  s.authors          = ["Petyo Ivanov", "Ilya Sabanin", "Artem Chistyakov"]
  s.email            = "ilya@wildbit.com"
  s.extra_rdoc_files = ["LICENSE", "README.md"]
  s.rdoc_options     = ["--charset=UTF-8"]

  s.summary          = "Official Postmark API wrapper."
  s.description      = "Use this gem to send emails through Postmark HTTP API and retrieve info about bounces."

  s.files            = `git ls-files`.split("\n")
  s.test_files       = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables      = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths    = ["lib"]

  s.post_install_message = %q{
    ==================
    Thanks for installing the postmark gem. If you don't have an account, please
    sign up at http://postmarkapp.com/.

    Review the README.md for implementation details and examples.
    ==================
  }

  s.required_rubygems_version = ">= 1.3.7"

  s.add_development_dependency "mail"
  s.add_development_dependency "rake"
end
