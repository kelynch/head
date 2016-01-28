Utils.configure do |config|
  fs_env_file = Rails.root.join("config", 'filesystem.yml')

  fail "Missing configuration file at: #{fs_env_file}." unless File.exist?(fs_env_file)

  begin
    fs_yml = YAML.load_file(fs_env_file)
  rescue StandardError
    raise("#{fs_env_file} was found, but could not be parsed.\n")
  end

  if File.exists?(fs_env_file)
    options = fs_yml.fetch(Rails.env).with_indifferent_access
    config.object_admin_path = options.fetch(:object_admin_path)
    config.object_manifest_location = options.fetch(:object_manifest_location)
    config.email = options.fetch(:email)
    config.assets_path = options.fetch(:assets_path)
    config.manifest_location = options.fetch(:manifest_location)
    config.federated_fs_path = options.fetch(:federated_fs_path)
    config.metadata_path_label = options.fetch(:metadata_path_label)
    config.file_path_label = options.fetch(:file_path_label)
    config.imports_local_staging = options.fetch(:imports_local_staging)
    config.repository_prefix = options.fetch(:repository_prefix)
    config.split_on = options.fetch(:split_on)
  end

end