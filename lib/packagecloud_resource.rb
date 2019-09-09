require 'packagecloud'
require 'multi_json'
require 'packagecloud/result'

module PackageCloudResource
class Out
class << self

    def fail_with(msg)
        raise msg
    end

    def get_link(username, repo, distribution, package_file)
        "https://packagecloud.io/#{username}/#{repo}/packages/#{distribution}/#{package_file}"
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
            response_content = MultiJson.load(result.response)
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
        result = client.list_dist_packages(repo, distribution)
        if result.succeeded != true
            fail_with("Failed to load packages for repo #{repo}")
        else
            $stderr.puts "Version regex #{delete_version}"
            packages = result.response
            packages.select do |package|
                if version_regexp.match(package['version']) == nil
                    $stderr.puts " Keeping version #{package['version']}"
                    false
                else
                    $stderr.puts "Removing version #{package['version']}"
                    true
                end
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

        if distribution.nil?
            fail_with("Distribution name should be set either in params or source")
        end

        if package_file_glob.nil? && delete_version.nil?
            fail_with("Either package_file_glob or delete_version should be set")
        elsif !package_file_glob.nil? && !delete_version.nil?
            fail_with("package_file_glob and delete_version should not be set in the same time")
        elsif !package_file_glob.nil? && delete_version.nil?
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
            {
                version: {"deleted" => "<DELETED>"},
                metadata: []
            }
        end
    end
end
end
end

module Packagecloud
class Client

    def list_dist_packages(repo, distribution)
        assert_valid_repo_name(repo)
        get_all("/api/v1/repos/#{username}/#{repo}/search.json?dist=#{distribution}&per_page=100", 1)
    end

    def get_all(url, page)
        page_url = "#{url}&page=#{page}"
        excon_result = request(page_url, :get)
        if excon_result.status == 200
            page_data = MultiJson.load(excon_result.body)
            total = excon_result.headers["Total"].to_i
            per_page = excon_result.headers["Per-Page"].to_i
            if total > per_page && page_data.length > 0
                other_pages = get_all(url, page+1)
                if other_pages.succeeded == true
                    result(true, page_data + other_pages.response)
                else
                    other_pages
                end
            else
                result(true, page_data)
            end
        else
            result(false, excon_result.body)
        end
    end

    def result(succeeded, response)
        result = Result.new
        result.response = response
        result.succeeded = succeeded
        result
    end

end
end
