module Utils
  module Derivatives

    extend self

    def generate_access_copy(file, directory, options = {})
      fname = "#{File.basename(file,".*")}.jpeg"
      width = options[:width] || "100"
      height = options[:height] || "200"
      image = MiniMagick::Image.open(file)
      image.resize "#{width}x#{height}"
      image.format "jpeg"
      derivative_link = "#{directory}/#{fname}"
      image.write(derivative_link)
      return fname
    end

  end
end
