# Concourse packagecloud resource

This is a concourse resource to publish package cloud packages.
**Java, Ruby and Python packages are not supported yet**

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

Distribution name can be one of distribution names described in [the packagecloud docs](https://packagecloud.io/docs#anchor-elementaryos)

**Please note, that ruby gem, java and python distributions are not supported**

### Behaviour

#### `check`: Does nothing.

#### `in`: Does nothing.

#### `out`: Publishes a package to package cloud


##### Parameters

- package_file_glob: a glob pattern for the package file.
- distribution_name: *Optional* a name of distribution. Overrides the source configuration.





