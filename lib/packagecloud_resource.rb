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
        %w{
            elementaryos/jupiter
            elementaryos/luna
            elementaryos/freya

            sles/11.4
            sles/12.0
            sles/12.1
            sles/12.2

            ubuntu/warty
            ubuntu/hoary
            ubuntu/breezy
            ubuntu/dapper
            ubuntu/edgy
            ubuntu/feisty
            ubuntu/gutsy
            ubuntu/hardy
            ubuntu/intrepid
            ubuntu/jaunty
            ubuntu/karmic
            ubuntu/lucid
            ubuntu/maverick
            ubuntu/natty
            ubuntu/oneiric
            ubuntu/precise
            ubuntu/quantal
            ubuntu/raring
            ubuntu/saucy
            ubuntu/trusty
            ubuntu/utopic
            ubuntu/vivid
            ubuntu/wily
            ubuntu/xenial
            ubuntu/yakkety
            ubuntu/zesty

            debian/etch
            debian/lenny
            debian/squeeze
            debian/wheezy
            debian/jessie
            debian/stretch
            debian/buster

            raspbian/wheezy
            raspbian/jessie
            raspbian/stretch
            raspbian/buster

            opensuse/13.1
            opensuse/13.2
            opensuse/42.1
            opensuse/42.2
            opensuse/42.3

            fedora/14
            fedora/15
            fedora/16
            fedora/17
            fedora/18
            fedora/19
            fedora/20
            fedora/21
            fedora/22
            fedora/23
            fedora/24
            fedora/25
            fedora/26

            linuxmint/petra
            linuxmint/qiana
            linuxmint/rebecca
            linuxmint/rafaela
            linuxmint/rosa
            linuxmint/sarah
            linuxmint/serena
            linuxmint/sonya

            poky/jethro
            poky/krogoth

            scientific/5
            scientific/6
            scientific/7

            ol/5
            ol/6
            ol/7

            el/5
            el/6
            el/7
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
        package_file = File.basename(package_file_location)

        delete_package(client, repo, distribution, package_file)

        ## Recursively try to republish the package
        publish_package(client, repo, package_file_location, distribution, override, attempts - 1)
    end

    def delete_package(client, repo, distribution, package_file)
        distribution_parts = distribution.split("/")
        distro_name = distribution_parts[0]
        distro_version = distribution_parts[1]
        ## Delete the package
        client.delete_package(repo, distro_name, distro_version, package_file)
    end

    def match_packages(client, repo, distribution, delete_version)
        version_regexp = Regexp.compile(delete_version)
        result = client.list_packages(repo)
        if result.succeeded != true
            fail_with("Failed to load packages for repo #{repo}")
        else
            packages = result.response
            packages.select do |package|
                (package['distro_version'] == distribution) && (version_regexp.match(package['version']) != nil)
            end.map do |package|
                package['filename']
            end
        end
    end

    def delete_versions(client, repo, distribution, delete_version)
        matching_packages = match_packages(client, repo, distribution, delete_version)
        matching_packages.each do |package_file|
            delete_package(client, repo, distribution, package_file)
        end
    end

    def main(work_dir, request)
        source = request.fetch("source")
        params = request.fetch("params")

        username = source.fetch("username")
        api_key = source.fetch("api_key")
        repo = source.fetch("repo")

        distribution = params.fetch("distribution_name", source.fetch("distribution_name", nil))
        package_file_glob = params.fetch("package_file_glob", nil)
        override = params.fetch("override", false)

        delete_version = params.fetch("delete_version", nil)

        if distribution == nil
            fail_with("Distribution name should be set either in params or source")
        end
        if not distributions().include?(distribution)
            fail_with("Distribution name not supported: #{distribution}")
        end

        if package_file_glob == nil and delete_version == nil
            fail_with("Either package_file_glob or delete_version should be set")
        elsif package_file_glob != nil and delete_version != nil
            fail_with("package_file_glob and delete_version should not be set in the same time")
        elsif package_file_glob != nil and delete_version == nil
            # Publish package
            package_file_location = Dir.glob([File.join(work_dir, package_file_glob)]).first
            if package_file_location == nil or not File.exists?(package_file_location)
                fail_with("Package file #{package_file_glob} not found in directory #{work_dir}")
            end

            client = make_client(username, api_key)
            publish_package(client, repo, package_file_location, distribution, override, 10)
        else
            # Delete versions
            client = make_client(username, api_key)
            delete_versions(client, repo, distribution, delete_version)
        end
    end
end
end
end