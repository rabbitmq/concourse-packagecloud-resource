require 'packagecloud'
require 'json'

module PackageCloudResource
class Out
class << self

    def fail_with(msg)
        raise msg
    end

    def get_link(username, repo, distribution, package_file)
        "https://packagecloud.io/#{username}/#{repo}/packages/#{distribution}/#{package_file}"
    end

    def distributions()
        {
            "debian-jessie" => "debian/jessie",
            "debian-wheezy" => "debian/wheezy",
            "debian-stretch" => "debian/stretch",
            "ubuntu-12.04" => "ubuntu/precise",
            "ubuntu-12.10" => "ubuntu/quantal",
            "ubuntu-13.04" => "ubuntu/raring",
            "ubuntu-13.10" => "ubuntu/saucy",
            "ubuntu-14.04" => "ubuntu/trusty",
            "ubuntu-14.10" => "ubuntu/utopic",
            "ubuntu-15.04" => "ubuntu/vivid",
            "ubuntu-15.10" => "ubuntu/wily",
            "ubuntu-16.04" => "ubuntu/xenial",
            "ubuntu-16.10" => "ubuntu/yakkety",
            "ubuntu-17.04" => "ubuntu/zesty",
            "centos-6" => "el/6",
            "fedora-24" => "fedora/24",
            "fedora-25" => "fedora/25",
            "fedora-26" => "fedora/26",
            "centos-7" => "el/7",
            "opensuse-leap-42.2" => "opensuse/42.2"
        }
    end

    def make_client(username, api_key)
        credentials = Packagecloud::Credentials.new(username, api_key)
        Packagecloud::Client.new(credentials)
    end

    def make_package(package_file_location)
        Packagecloud::Package.new(:file => package_file_location)
    end

    def gen_version(client, repo, distribution, package_file_location)
        package_file = File.basename(package_file_location)
        link = get_link(client.credentials.username, repo, distribution, package_file)
        {
            version: {package: link},
            metadata: [
                {name: "Filename", value: package_file},
                {name: "Package link", value: link}]
        }
    end

    def publish_package(client, repo, package_file_location, distribution, override, attempts)
        package = make_package(package_file_location)

        result = client.put_package(repo, package, distribution)

        if result.succeeded
            gen_version(client, repo, distribution, package_file_location)
        else
            response_content = JSON.parse(result.response)
            if response_content["filename"] == ["has already been taken"]
                if override
                    override_package(client, repo, package_file_location, distribution, override, attempts)
                else
                    gen_version(client, repo, distribution, package_file_location)
                end
            else
                fail_with(result.inspect)
            end
        end
    end

    def override_package(client, repo, package_file_location, distribution, override, attempts)
        if attempts == 0
            fail_with("Unable to override the package. No more attempts left")
        end
        distribution_parts = distribution.split("/")
        distro_name = distribution_parts[0]
        distro_version = distribution_parts[1]
        package_file = File.basename(package_file_location)

        ## Delete the package
        client.delete_package(repo, distro_name, distro_version, package_file)

        ## Recursively try to republish the package
        publish_package(client, repo, package_file_location, distribution, override, attempts - 1)
    end

    def main(work_dir, request)
        source = request.fetch("source")
        params = request.fetch("params")

        username = source.fetch("username")
        api_key = source.fetch("api_key")
        repo = source.fetch("repo")

        distribution_name = params.fetch("distribution_name", source.fetch("distribution_name", nil))
        package_file_glob = params.fetch("package_file_glob")
        override = params.fetch("override", false)

        distribution = distributions[distribution_name]
        if distribution_name == nil
            fail_with("Distribution name should be set either in params or source")
        end
        if distribution == nil
            fail_with("Distribution name not supported: #{distribution_name}")
        end

        package_file_location = Dir.glob([File.join(work_dir, package_file_glob)]).first
        if package_file_location == nil or not File.exists?(package_file_location)
            fail_with("Package file #{package_file_glob} not found in directory #{work_dir}")
        end

        client = make_client(username, api_key)
        publish_package(client, repo, package_file_location, distribution, override, 10)
    end
end
end
end