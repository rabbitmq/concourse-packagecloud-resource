require "spec_helper"
require "tmpdir"
require "fileutils"

class MockResult
    attr_reader :succeeded
    attr_reader :response
    def initialize(succeeded, response)
        @succeeded = succeeded
        @response = response
    end
end

class MockClient
    attr_reader :credentials
    attr_reader :packages_published
    attr_reader :packages_deleted
    attr_reader :packages
    def initialize()
        @packages = {}
        @packages_published = {}
        @packages_deleted = {}
    end
    def auth(username, api_key)
        if username != "test_username" or api_key != "valid_key"
            raise "failed"
        end
        @credentials = Packagecloud::Credentials.new(username, api_key)
    end
    def put_package(repo, package, distribution)
        package_file = File.basename(package.file)
        arg_hash = [repo, package_file, distribution].hash
        if @packages[arg_hash]
            MockResult.new(false, '{"filename":["has already been taken"]}')
        else
            @packages[arg_hash] = {repo: repo, package_file: package_file, distribution: distribution}
            counter = @packages_published[arg_hash] || 0
            @packages_published[arg_hash] = counter + 1
            MockResult.new(true, '{}')
        end
    end
    def delete_package(repo, distro_name, distro_version, package_file)
        arg_hash = [repo, package_file, "#{distro_name}/#{distro_version}"].hash
        counter = @packages_deleted[arg_hash] || 0
        @packages_deleted[arg_hash] = counter + 1
        @packages.delete(arg_hash)
    end
    def list_packages(repo)
        packages = @packages.map do |k, package|
            {"repo" => package[:repo],
             "filename" => package[:package_file],
             "distro_version" => package[:distribution],
             "version" => version(package[:package_file])}
        end.select do |package|
            package["repo"] == repo
        end
        MockResult.new(true, packages)
    end

    def version(package_name)
        /some_(.*)\.deb/.match(package_name)[1]
    end
end

describe "Out Command" do
    let(:client) {MockClient.new()}
    def in_dir
        dir = Dir.mktmpdir
        begin
            yield dir
        ensure
            FileUtils.remove_entry dir
        end
    end

    before do
        allow(PackageCloudResource::Out).to receive(:make_client) do |username, api_key|
            client.auth(username, api_key)
            client
        end
    end

    context "with valid repo input" do
        let(:config) { {"source" => {"username" => "test_username",
                                     "api_key" => "valid_key",
                                     "repo" => "test_repo"},
                        "params" => {"distribution_name" => "debian/jessie",
                                     "package_file_glob" => "*.deb"}} }
        it "publishes a package" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                result = PackageCloudResource::Out.main(out_dir, config)
                expect(result).to include(:version)
                expect(result).to include(:metadata)

                version = result[:version]
                expect(version).to include(:package)

                package = version[:package]
                expect(package).to match(/https:\/\/packagecloud\.io/)
                expect(package).to match(/debian\/jessie/)
                expect(package).to match(/test_repo/)
                expect(package).to match(/#{filename}/)

                arg_hash = ["test_repo", filename, "debian/jessie"].hash
                expect(client.packages_published[arg_hash]).to eq(1)
                expect(client.packages_deleted[arg_hash]).to eq(nil)
            end
        end

        it "publishes package once and returns the same version" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                result1 = PackageCloudResource::Out.main(out_dir, config)
                expect(result1).to include(:version)
                expect(result1).to include(:metadata)

                result2 = PackageCloudResource::Out.main(out_dir, config)
                expect(result2).to include(:version)
                expect(result2).to include(:metadata)

                expect(result1).to eq(result2)

                arg_hash = ["test_repo", filename, "debian/jessie"].hash
                expect(client.packages_published[arg_hash]).to eq(1)
                expect(client.packages_deleted[arg_hash]).to eq(nil)
            end
        end

        context "if both package_file_glob and delete_version set" do
            let(:config) { {"source" => {"username" => "test_username",
                                     "api_key" => "valid_key",
                                     "repo" => "test_repo"},
                        "params" => {"distribution_name" => "debian/jessie",
                                     "package_file_glob" => "*.deb",
                                     "delete_version" => ".*"}} }
            it "fails" do
                in_dir do |working_dir|
                    out_dir = File.join(working_dir, "path")
                    Dir.mkdir(out_dir)
                    filename = "some.deb"
                    File.open(File.join(out_dir, filename), "w") {}
                    expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error("package_file_glob and delete_version should not be set in the same time")
                end
            end
        end

        it "clean up package versions if delete_version is provided" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some_3.6.13~alpha.39-1_all.deb"
                File.open(File.join(out_dir, filename), "w") {}
                result = PackageCloudResource::Out.main(out_dir, config)
                expect(result).to include(:version)
                expect(result).to include(:metadata)

                File.delete(File.join(out_dir, filename))

                filename1 = "some_3.6.14~alpha.39-1_all.deb"
                File.open(File.join(out_dir, filename1), "w") {}
                result = PackageCloudResource::Out.main(out_dir, config)
                expect(result).to include(:version)
                expect(result).to include(:metadata)

                expect(client.packages_published.length).to eq(2)
                expect(client.packages_deleted.length).to eq(0)

                config["params"] = {"distribution_name" => "debian/jessie",
                                    "delete_version" => "^3\.6\.14"}

                result = PackageCloudResource::Out.main(out_dir, config)
                expect(result[:version]).to eq({"deleted" => "<DELETED>"})

                expect(client.packages_published.length).to eq(2)

                arg_hash = ["test_repo", filename1, "debian/jessie"].hash
                expect(client.packages_deleted[arg_hash]).to eq(1)
                expect(client.packages.length).to eq(1)

                expected = [{"repo" => "test_repo",
                             "filename" => filename,
                             "distro_version" => "debian/jessie",
                             "version" => "3.6.13~alpha.39-1_all"}]
                expect(client.list_packages('test_repo').response).to eq(expected)
            end
        end
    end

    context "with valid repo input and override" do
        let(:config) { {"source" => {"username" => "test_username",
                                     "api_key" => "valid_key",
                                     "repo" => "test_repo"},
                        "params" => {"distribution_name" => "debian/jessie",
                                     "package_file_glob" => "*.deb",
                                     "override" => true}} }
        it "publishes a package" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                result = PackageCloudResource::Out.main(out_dir, config)
                expect(result).to include(:version)
                expect(result).to include(:metadata)

                version = result[:version]
                expect(version).to include(:package)

                package = version[:package]
                expect(package).to match(/https:\/\/packagecloud\.io/)
                expect(package).to match(/debian\/jessie/)
                expect(package).to match(/test_repo/)
                expect(package).to match(/#{filename}/)

                arg_hash = ["test_repo", filename, "debian/jessie"].hash
                expect(client.packages_published[arg_hash]).to eq(1)
                expect(client.packages_deleted[arg_hash]).to eq(nil)
            end
        end
        it "deletes and republishes package" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                result1 = PackageCloudResource::Out.main(out_dir, config)
                expect(result1).to include(:version)
                expect(result1).to include(:metadata)

                result2 = PackageCloudResource::Out.main(out_dir, config)
                expect(result2).to include(:version)
                expect(result2).to include(:metadata)

                expect(result1).to eq(result2)

                arg_hash = ["test_repo", filename, "debian/jessie"].hash
                expect(client.packages_published[arg_hash]).to eq(2)
                expect(client.packages_deleted[arg_hash]).to eq(1)
            end
        end
    end

    context "with valid repo and distribution input and override" do
        let(:config) { {"source" => {"username" => "test_username",
                                     "api_key" => "valid_key",
                                     "repo" => "test_repo",
                                     "distribution_name" => "debian/jessie"},
                        "params" => {"package_file_glob" => "*.deb",
                                     "override" => true}} }
        it "publishes a package" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                result = PackageCloudResource::Out.main(out_dir, config)
                expect(result).to include(:version)
                expect(result).to include(:metadata)

                version = result[:version]
                expect(version).to include(:package)

                package = version[:package]
                expect(package).to match(/https:\/\/packagecloud\.io/)
                expect(package).to match(/debian\/jessie/)
                expect(package).to match(/test_repo/)
                expect(package).to match(/#{filename}/)

                arg_hash = ["test_repo", filename, "debian/jessie"].hash
                expect(client.packages_published[arg_hash]).to eq(1)
                expect(client.packages_deleted[arg_hash]).to eq(nil)
            end
        end
        it "deletes and republishes package" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                result1 = PackageCloudResource::Out.main(out_dir, config)
                expect(result1).to include(:version)
                expect(result1).to include(:metadata)

                result2 = PackageCloudResource::Out.main(out_dir, config)
                expect(result2).to include(:version)
                expect(result2).to include(:metadata)

                expect(result1).to eq(result2)

                arg_hash = ["test_repo", filename, "debian/jessie"].hash
                expect(client.packages_published[arg_hash]).to eq(2)
                expect(client.packages_deleted[arg_hash]).to eq(1)
            end
        end
    end

    context "with invalid config" do
        let(:valid_config) { {"source" => {"username" => "test_username",
                                     "api_key" => "valid_key",
                                     "repo" => "test_repo",
                                     "distribution_name" => "debian/jessie"},
                        "params" => {"package_file_glob" => "*.deb",
                                     "override" => true}} }
        it "fails if username or api_key is invalid" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}

                config = valid_config
                config["source"]["username"] = "invalid"
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error("failed")
                config = valid_config
                config["source"]["api_key"] = "invalid"
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error("failed")
            end
        end
        it "fails if distribution name is invalid" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}

                config = valid_config
                config["source"]["distribution_name"] = "devian-whoozy"
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error("Distribution name not supported: devian-whoozy")
            end
        end
        it "fails if file not found" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}

                config = valid_config
                config["params"]["package_file_glob"] = "non_existent_file"
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error("Package file non_existent_file not found in directory #{out_dir}")
            end
        end
        it "fails if no distribution_name set missing" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                config = valid_config
                config["source"].delete("distribution_name")
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error("Distribution name should be set either in params or source")
            end
        end
        it "fails if required parameter is missing" do
            in_dir do |working_dir|
                out_dir = File.join(working_dir, "path")
                Dir.mkdir(out_dir)
                filename = "some.deb"
                File.open(File.join(out_dir, filename), "w") {}
                config = valid_config
                config["source"].delete("username")
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error(KeyError)
                config = valid_config
                config["source"].delete("api_key")
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error(KeyError)
                config = valid_config
                config["source"].delete("repo")
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error(KeyError)
                config = valid_config
                config["params"].delete("package_file_glob")
                expect {PackageCloudResource::Out.main(out_dir, config)}.to raise_error(KeyError)
            end
        end
    end
end