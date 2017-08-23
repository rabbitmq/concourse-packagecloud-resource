# Concourse packagecloud resource

This is a concourse resource to publish package cloud packages.

## Building

This resource is a ruby gem, which can be build via

```
gem build packagecloud_resource.gemspec
```

The gem contains three executables `pcr_check`, `pcf_in` and `pcf_out`,
which are used as `check`, `in` and `out` commands for the resource.

## Usage

### Source Configuration

- username: Package cloud username
- api_key: Package cloud api token
- repo: Package cloud repo name
- distribution_name: *Optional* a name of distribution. Can be overriden by the same configuration in `out` params.

Distribution name can be one of:

- debian-jessie
- debian-wheezy
- debian-stretch
- ubuntu-12.04
- ubuntu-12.10
- ubuntu-13.04
- ubuntu-13.10
- ubuntu-14.04
- ubuntu-14.10
- ubuntu-15.04
- ubuntu-15.10
- ubuntu-16.04
- ubuntu-16.10
- ubuntu-17.04
- centos-6
- fedora-24
- fedora-25
- fedora-26
- centos-7
- opensuse-leap-42.2

### Behaviour

#### `check`: Does nothing.

#### `in`: Does nothing.

#### `out`: Publishes a package to package cloud


##### Parameters

- package_file_glob: a glob pattern for the package file.
- distribution_name: *Optional* a name of distribution. Overrides the source configuration.





