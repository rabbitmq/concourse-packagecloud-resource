# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "packagecloud_resource"
  spec.version       = "0.0.1"
  spec.summary       = "Concourse resource to publish packages to packagecloud"
  spec.authors       = ["Daniil Fedotov"]

  spec.files         = Dir.glob("{lib,bin}/*")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }

  spec.add_dependency "json", "~> 1.8"
  spec.add_dependency "packagecloud-ruby", "~> 1.0"

  spec.add_development_dependency "bundler", "~> 1.15"
end