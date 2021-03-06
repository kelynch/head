require 'open-uri'

class ReposController < ApplicationController
  before_action :set_repo, only: [:show, :update, :checksum_log, :review_status, :detect_metadata, :preview_xml_preview, :fetch_by_ark]

  def new
  end

  def create
    @repo = Repo.new
  end

  def show
    @message = @repo.create_remote
    redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/git_actions"
  end

  def update
    if @repo.update(repo_params)
      redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/git_actions", :flash => { :success => t('colenda.controllers.repos.update.success')}
    else
      redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/git_actions", :flash => { :error => t('colenda.controllers.repos.update.error')}
    end
  end

  def checksum_log
    @message = Utils.generate_checksum_log("#{Utils.config[:assets_path]}/#{@repo.names.directory}")
    redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/ingest", :flash => { @message.keys.first => @message.values.first }
  end

  def review_status
    @message = @repo.update(repo_params)
    redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/ingest", :flash => { :success => t('colenda.controllers.repos.review_status.success') }
  end

  def preview_xml_preview
    @message = @repo.preview_xml_preview
    redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/preview_xml", :flash => { @message.keys.first => @message.values.first }
  end

  def detect_metadata
    @message = @repo.detect_metadata_sources
    redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/map_metadata", :flash => { @message.keys.first => @message.values.first }
  end

  def fetch_by_ark
    @repo.set_metadata_from_ark
    redirect_to "#{root_url}admin_repo/repo/#{@repo.id}/generate_metadata"
  end

  def download
    redirect_to "http://localhost:9292/files/#{params[:filename]}?filename=#{params[:download_url]}"
  end

  def fetch_image_ids
    repo = Repo.find_by(unique_identifier: "ark:/#{params[:id].tr('-','/')}")
    result = {}

    unless repo.nil?
      if repo.images_to_render.key?('iiif')
        ids = repo.images_to_render['iiif']['images']
      else
        ids = legacy_image_list(repo)
      end
      ids.map! { |id| id.gsub(ENV['IIIF_IMAGE_SERVER'], '').gsub(/^[^=]*=/, '').gsub('/info.json', '') } unless ids.is_a? Hash
      title = [repo.descriptive_metadata.user_defined_mappings['title']].flatten.join("; ")
      reading_direction = repo.images_to_render['iiif'].present? ? repo.images_to_render['iiif']['reading_direction'] : "left-to-right"
      result = { id: params[:id], title: title, reading_direction: reading_direction, image_ids: ids }
    end

    render json: JSON(result)
  end

  private
    def set_repo
      @repo = Repo.find(params[:id])
    end

    def repo_params
      params[:repo][:review_status] = format_review_status(params[:repo][:review_status]) if params[:repo][:review_status].present?
      params.require(:repo).permit(:title, :unique_identifier, :description, :metadata_subdirectory, :assets_subdirectory, :metadata_filename, :file_extensions, :version_control_agent, :preservation_filename, :review_status, :owner)
    end

    def format_review_status(message)
      message << t('colenda.controllers.repos.review_status.suffix', :email => current_user.email, :timestamp => Time.now)
      message
    end

    def legacy_image_list(repo)
      display_array = []
      repo.metadata_builder.get_structural_filenames.each do |filename|
        entry = repo.file_display_attributes.select{|key, hash| hash[:file_name].split('/').last == "#{filename}.jpeg"}
        display_array << entry.keys.first
      end

      return display_array.map{|k|"#{Display.config['iiif']['image_server']}#{repo.names.bucket}%2F#{k}/info.json"}
    end

end
