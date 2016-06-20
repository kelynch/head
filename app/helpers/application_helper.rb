module ApplicationHelper
  def fetch_files(doc)
    model = doc['active_fedora_model_ssi']
    if model == "Manuscript"
      @image_array = Array.new
      manuscript = model.constantize.find(doc.id)
      pages = Page.where(parent_manuscript: manuscript.id).to_a.sort_by! {|p| p.page_number}
      pages.each do |page|
        file_print = page.pageImage.uri
        @image_array.push(file_print.to_s.html_safe)
      end
    end
    return @image_array
  end

  def flash_class(level)
    case level
      when :notice then "alert alert-info"
      when :success then "alert alert-success"
      when :error then "alert alert-error"
      when :alert then "alert alert-error"
    end
  end
end
