=begin
  PDF & VIDEO BLOB handling
  =========================

  https://developer.mozilla.org/en-US/docs/Using_files_from_web_applications#Example_Using_object_URLs_to_display_images

  EXAMPLE: Using object URLs to display PDF
  -----------------------------------------

    Object URLs can be used for other things than just images! They can be used to display embedded PDF files or any other resources that can be displayed by the browser.

    In Firefox, to have the PDF appear embedded in the iframe
    (rather than proposed as a downloaded file),the preference
    pdfjs.disabled must be set to false .

    HTML:
      <iframe id="viewer">

    JAVASCRIPT:
      var obj_url = window.URL.createObjectURL(blob);
      var iframe = document.getElementById('viewer');
      iframe.setAttribute('src', obj_url);
      window.URL.revokeObjectURL(obj_url);

  EXAMPLE: Using object URLs with other file types
  ------------------------------------------------

    You can manipulate files of other formats the same way.
    Here is how to preview uploaded video:

    JAVASCRIPT
      var video = document.getElementById('video');
      var obj_url = window.URL.createObjectURL(blob);
      video.src = obj_url;
      video.play()
      window.URL.revokeObjectURL(obj_url);

  SEE ALSO
  --------
    http://pdfmake.org/#/

=end

require 'robe/client/dom/tag'

module Robe; module Client; module DOM
  class PDF

    # bytes should be string of space separated byte values, or array of integers
    def initialize(bytes)
      bytes = bytes.is_a?(String) ? bytes.split(' ').map(&:to_i) : bytes.to_a
      @bytes = `new Uint8Array(bytes)` # don't use Uint8Array.from - fails in Safari
    end

    def blob
      @blob ||= `new Blob([#{@bytes}], { type:'application/pdf' })`
    end

    def url
      @url ||= `window.URL.createObjectURL(#{blob})`
      trace __FILE__, __LINE__, self, __method__, " @url = #{@url}"
      @url
    end

    def revoke_url
      if @url
        `window.URL.revokeObjectURL(#{@url})`
        @url = nil
      end
    end

    module Tag
      module_function

      def pdf_anchor(pdf: nil, content: nil, **attributes)
        tag(:a, **{content: content, href: pdf.url}.merge(attributes))
      end

      def pdf_iframe(pdf, **attributes)
        tag(:iframe, **{src: pdf.url}.merge(attributes))
      end

    end
  end

end end end