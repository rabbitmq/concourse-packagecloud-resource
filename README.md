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

### Behaviour

#### `check`: Does nothing.

#### `in`: Does nothing.

#### `out`: Publishes a package to package cloud


##### Parameters

- distribution_name: a name of distribution.
- package_file_glob: a glob pattern for the package file.

Distribution name can be one of:

- debian-jessie
- debian-wheezy
- debian-stretch
- ubuntu-14.04
- ubuntu-16.04
- ubuntu-16.10
- centos-6
- fedora-24
- fedora-25
- fedora-26
- centos-7
- opensuse-leap-42.2




