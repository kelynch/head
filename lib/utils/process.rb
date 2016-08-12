module Utils
  module Process

    @@status_message
    @@status_type

    @@derivatives_working_destination

    extend self

    def import(file, repo)
      @oid = File.basename(repo.unique_identifier)
      @@derivatives_working_destination = "#{repo.version_control_agent.working_path}/#{repo.derivatives_subdirectory}"
      @@status_type = :error
      delete_duplicate(@oid)
      @command = _build_command("import", :file => file)
      @@status_message = contains_blanks(file) ? "Object(s) missing identifier.  Please check metadata source." : _execute_curl
      if check_persisted(@oid)
        object_and_descendants_action(@oid, "update_index")
      end
      ActiveFedora::Base.where(:id => @oid).first.try(:attach_files, repo)
      thumbnail = generate_thumbnail(repo)
      if thumbnail.present?
        repo.has_thumbnail = true
        @command = _build_command("file_attach", :file => thumbnail, :fid => repo.unique_identifier, :child_container => "thumbnail")
        _execute_curl
      else
        repo.has_thumbnail = false
      end
      repo.save!
      repo.version_control_agent.add(:add_location => "#{@@derivatives_working_destination}")
      repo.version_control_agent.commit("Generated derivatives for #{@oid}")
      repo.version_control_agent.push
      @@status_type = :success
      @@status_message = "Ingestion complete.  See link(s) below to preview ingested items associated with this repo.\n"
      return {@@status_type => @@status_message}
    end

    def delete_duplicate(object_id)
      obj = ActiveFedora::Base.where(:id => object_id).first
      if obj.present?
        object_and_descendants_action(object_id, "delete")
        @command = _build_command("delete_tombstone", :object_uri => obj.translate_id_to_uri.call(obj.id))
        _execute_curl
      end
    end

    def attach_file(repo, parent, file_name, child_container = "child")
      file_link = "#{repo.version_control_agent.working_path}/#{repo.assets_subdirectory}/#{file_name}"
      repo.version_control_agent.get(:get_location => file_link)
      repo.version_control_agent.unlock(file_link)
      validated = validate_file(file_link) if File.exist?(file_link)
      if(File.exist?(file_link) && validated)
        derivative_link = "#{Utils.config.federated_fs_path}/#{repo.directory}/#{repo.derivatives_subdirectory}/#{Utils::Derivatives::Access.generate_copy(file_link, @@derivatives_working_destination)}"
        @command = _build_command("file_attach", :file => derivative_link, :fid => parent.id, :child_container => child_container)
        _execute_curl
        repo.version_control_agent.add(:add_location => "#{@@derivatives_working_destination}")
        repo.version_control_agent.commit("Generated derivative for #{parent.file_name}")
      else
        @@status_type = :warning
        if File.exist?(file_link)
          @@status_message << "Image #{repo.assets_subdirectory}/#{file_name} did not pass validation.  No derivatives made or attached.\n"
        else
          @@status_message << "Image #{repo.assets_subdirectory}/#{file_name} not detected in file directory.  No derivatives made or attached.\n"
        end
      end
    end

    def generate_thumbnail(repo)
      unencrypted_thumbnail_path = "#{repo.version_control_agent.working_path}/#{repo.assets_subdirectory}/#{ActiveFedora::Base.where(:id => repo.unique_identifier).first.cover.file_name}"
      thumbnail_link = File.exist?(unencrypted_thumbnail_path) ? "#{Utils.config.federated_fs_path}/#{repo.directory}/#{repo.derivatives_subdirectory}/#{Utils::Derivatives::Thumbnail.generate_copy(unencrypted_thumbnail_path, @@derivatives_working_destination)}" : ""
      return thumbnail_link
    end

    def refresh_assets(repo)
      display_path = "#{Utils.config.assets_display_path}/#{repo.directory}"
      if File.directory?("#{Utils.config.assets_display_path}/#{repo.directory}")
        Dir.chdir(display_path)
        repo.version_control_agent.sync_content
      else
        repo.version_control_agent.clone(:destination => display_path)
        refresh_assets(repo)
      end
    end

    protected

    def validate_file(file)
      begin
        MiniMagick::Image.open(file)
        return true
      rescue MiniMagick::Invalid
        return false
      end
    end

    def contains_blanks(file)
      status = File.read(file) =~ /<sv:node sv:name="">/
      return status.nil? ? false : true
    end

    def object_and_descendants_action(parent_id, action)
      uri = ActiveFedora::Base.id_to_uri(parent_id)
      refresh_ldp_contains(uri)
      descs = ActiveFedora::Base.descendant_uris(uri)
      descs.each do |desc|
        begin
          ActiveFedora::Base.find(ActiveFedora::Base.uri_to_id(desc)).send(action)
        rescue
          next
        end
      end
    end

    def check_persisted(object_id)
      Ldp::Orm.new(Ldp::Resource::RdfSource.new(ActiveFedora.fedora.connection, ActiveFedora::Base.id_to_uri(object_id))).persisted?
    end

    def refresh_ldp_contains(container_uri)
      resource = Ldp::Resource::RdfSource.new(ActiveFedora.fedora.connection, container_uri)
      orm = Ldp::Orm.new(resource)
      orm.graph.delete
      orm.save
    end

    private

    @fedora_yml = "#{Rails.root}/config/fedora.yml"
    fedora_config = YAML.load_file(File.expand_path(@fedora_yml, __FILE__))
    @fedora_user = fedora_config['development']['user']
    @fedora_password = fedora_config['development']['password']
    @fedora_link = "#{fedora_config['development']['url']}#{fedora_config['development']['base_path']}"

    def _build_command(type, options = {})
      child_container = options[:child_container]
      file = options[:file]
      fid = options[:fid]
      object_uri = options[:object_uri]
      case type
      when "import"
        command = "curl -u #{@fedora_user}:#{@fedora_password} -X POST --data-binary \"@#{file}\" \"#{@fedora_link}/fcr:import?format=jcr/xml\""
      when "file_attach"
        fedora_full_path = "#{@fedora_link}/#{fid}/#{child_container}"
        command = "curl -u #{@fedora_user}:#{@fedora_password}  -X PUT -H \"Content-Type: message/external-body; access-type=URL; URL=\\\"#{file}\\\"\" \"#{fedora_full_path}\""
      when "delete"
        command = "curl -u #{@fedora_user}:#{@fedora_password} -X DELETE \"#{object_uri}\""
      when "delete_tombstone"
        command = "curl -u #{@fedora_user}:#{@fedora_password} -X DELETE \"#{object_uri}/fcr:tombstone\""
      else
        raise "Invalid command type specified.  Command not built."
      end
      return command
    end

    def _execute_curl
      `#{@command}`
    end

  end
end
