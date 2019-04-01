# Concourse packagecloud resource

This is a concourse resource to publish package cloud packages.
**Java, Ruby and Python packages are not supported yet**

## Installing

```yaml
---
resource_types:
- name: packagecloud
  type: docker-image
  source:
    repository: pivotalrabbitmq/packagecloud-package-resource
    tag: latest
```

## Building

This resource is a ruby gem, which can be build via

```
gem build packagecloud_resource.gemspec
```

The gem contains three executables: `pcr_check`, `pcr_in` and `pcr_out`,
which are used as `check`, `in` and `out` commands for the resource.

## Usage

### Source Configuration

```yaml
resources:
- name: packagecloud_upload
  type: packagecloud
  source:
    username: {{packagecloud-username}}
    api_key: {{packagecloud-api-key}}
    repo: {{packagecloud-repo}}
    distribution_name: el/7
```

* `username`: Package cloud username
* `api_key`: Package cloud API token
* `repo`: Package cloud repository name
* `distribution_name`: *Optional* a name of distribution. Can be overriden by the same configuration in `out` params.

Distribution name can be one of distribution names described in [the packagecloud docs](https://packagecloud.io/docs#anchor-elementaryos). Note that you must have a separate resource for each distribution.

**Please note, that ruby gem, java and python distributions are not supported**

### Example Pipeline Configuration

```yaml
- task: mytask
 [..........]
  - put: packagecloud_upload
    params:
    package_file_glob: gpdb_rpm_installer/*.rpm
```

### Behaviour

#### `check`: Does nothing.

#### `in`: Does nothing.

#### `out`: Publishes a package to package cloud or deletes packages by version pattern


##### Parameters

* `distribution_name`: *Optional* a name of distribution. Overrides the source configuration.
* `package_file_glob`: *Optional* a glob pattern for the package file.
* `delete_version`: *Optional* version pattern to delete. If set, will delete packages with matching version.
* `override`: *Optional* if set, it will delete and recreate the package, otherwise - ignore

Either `package_file_glob` or `delete_version` should be set.



## Related
[Concourse bintray resource](https://github.com/rabbitmq/concourse-bintray-resources)
