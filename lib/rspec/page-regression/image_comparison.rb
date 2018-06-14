if RUBY_PLATFORM == 'java'
  require "chunky_png"
else
  require 'oily_png'
end

module RSpec::PageRegression

  class ImageComparison
    include ChunkyPNG::Color

    attr_reader :result
    attr_reader :filepaths

    def initialize(filepaths)
      @filepaths = filepaths
      @result = compare
    end

    def expected_size
      [@iexpected.width , @iexpected.height]
    end

    def test_size
      [@itest.width , @itest.height]
    end

    private
    def build_overwrite_command(test_screenshot, reference_screenshot)
      "mkdir -p #{reference_screenshot.dirname} && cp #{test_screenshot} #{reference_screenshot}"
    end

    def handle_missing_screenshot(autocreate_reference_screenshots, test_screenshot, reference_screenshot)
      overwrite_command = build_overwrite_command(test_screenshot, reference_screenshot)
      if autocreate_reference_screenshots
				puts "Creating missing screenshot #{reference_screenshot}"
				system overwrite_command
			else
				puts "Create screenshot yourself with:\n#{overwrite_command}"
      end
    end

    def overwrite_existing_screenshot(test_screenshot, reference_screenshot)
      overwrite_command = build_overwrite_command(test_screenshot, reference_screenshot)
			#puts "Updating existing screenshot #{reference_screenshot}"
			system overwrite_command
    end

    def compare
      test_screenshot      = @filepaths.test_screenshot
      reference_screenshot = @filepaths.reference_screenshot
      difference_image     = @filepaths.difference_image

      if difference_image.exist?
        difference_image.unlink
        raise "Unlinking difference_image failed" if difference_image.exist?
      end

      autoupdate_reference_screenshots = RSpec::PageRegression.autoupdate_reference_screenshots
      autocreate_reference_screenshots = RSpec::PageRegression.autocreate_reference_screenshots

      if reference_screenshot.exist? && autoupdate_reference_screenshots
        overwrite_existing_screenshot(test_screenshot, reference_screenshot)
      else
        handle_missing_screenshot(autocreate_reference_screenshots, test_screenshot, reference_screenshot)
      end

      return :missing_reference_screenshot unless reference_screenshot.exist?
      return :missing_test_screenshot      unless test_screenshot.exist?

      @iexpected = ChunkyPNG::Image.from_file(reference_screenshot)
      @itest     = ChunkyPNG::Image.from_file(test_screenshot)

      #return :size_mismatch if test_size != expected_size
      puts "Size Mismatch" if test_size != expected_size
      return :match         if pixels_match?

      create_difference_image
      return :difference
    end

    def pixels_match?
      max_count = RSpec::PageRegression.threshold * @itest.width * @itest.height
      count = 0
      @itest.height.times do |y|
        next if @itest.row(y) == @iexpected.row(y)
        diff = @itest.row(y).zip(@iexpected.row(y)).select { |x, y| x != y }
        count += diff.count
        return false if count > max_count
      end
      return true
    end

    def create_difference_image
      idiff = ChunkyPNG::Image.from_file(@filepaths.reference_screenshot)
      xmin = @itest.width + 1
      xmax = -1
      ymin = @itest.height + 1
      ymax = -1
      @itest.height.times do |y|
        @itest.row(y).each_with_index do |test_pixel, x|
          idiff[x,y] = if test_pixel != (expected_pixel = idiff[x,y])
                         xmin = x if x < xmin
                         xmax = x if x > xmax
                         ymin = y if y < ymin
                         ymax = y if y > ymax
                         rgb(
                             (r(test_pixel) - r(expected_pixel)).abs,
                             (g(test_pixel) - g(expected_pixel)).abs,
                             (b(test_pixel) - b(expected_pixel)).abs
                         )
                       else
                         rgb(0,0,0)
                       end
        end
      end

      idiff.rect(xmin-1,ymin-1,xmax+1,ymax+1,rgb(255,0,0))

      idiff.save @filepaths.difference_image
    end
  end
end
