
require 'omf_common/lobject'
require 'omf-web/widget'
require 'labwiki/theme/col_content_renderer'

module LabWiki    
  
  # Responsible for the content to be shown in a particular column 
  class ColumnWidget < OMF::Common::LObject
    
    attr_reader :embedded_widget, :name, :content_descriptor

    def initialize(name)
      @name = name
    end
    
    # def empty?
      # @embedded_widget.nil?
    # end
#     
    # def mime_type
      # @embedded_widget ? @embedded_widget.mime_type : 'unknown'
    # end
    
    # def on_get(opts, req)
      # @content_descriptor = opts[:content_descriptor]
    # end
    
    def parse_req_params(params, req)
      h = {}
      if cd = h[:content_descriptor] = params[:content]
        h[:mime_type], h[:path] = Base64.decode64(cd).split('::')
        unless h[:mime_type] && h[:path]
          raise OMF::Web::Rack::MissingArgumentException.new "Can't decode 'content' parameter (#{cd})"
        end
      end
      h
    end
    
    
    
    def collect_data_sources(ds_set)
      if @embedded_widget
        @embedded_widget.collect_data_sources(ds_set)
      end
      ds_set
    end
  end
end
