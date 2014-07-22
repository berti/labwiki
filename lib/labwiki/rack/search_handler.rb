require 'base64'
require 'json'
require 'labwiki/rack/abstract_handler'
require 'labwiki/labwiki_widget'
require 'omf-web/content/repository'

module LabWiki
  # Thrown by widget when the UI should retry the query later
  class RetrySearchLaterException < Exception; end
  class NoReposToSearchException < Exception; end

  class SearchHandler < AbstractHandler

    def on_request(req)
      debug "Search params: #{req.params.inspect}"

      col = req.params['col']
      unless (pat = req.params['pat'])
        raise OMF::Web::Rack::MissingArgumentException.new "Missing parameter 'pat'"
      end
      begin
        res = search(pat, col)
      rescue RetrySearchLaterException
        return [{retry: true}.to_json, 'application/json']
      rescue NoReposToSearchException
        return [{warn: 'No repository defined'}.to_json, 'application/json']
      end
      [{result: res}.to_json, 'application/json']
    end

    def search(pat, col)
      opts = {:max => 10}
      unless opts[:repo_iterator] = OMF::Web::SessionStore[col.to_sym, :repos]
        warn "No search repo defined for '#{col}'"
        raise NoReposToSearchException.new
      end
      result = PluginManager.widgets_for_column(col).map do |widget|
        next unless sproc = widget[:search]
        name = widget[:name]
        wopts = Configurator["plugins/#{name}"]
        cl = (sproc.call(pat, opts, wopts) || [])
        cl.map do |f|
          f[:widget] = name
          url = f.delete(:url)
          f[:label] ||= url
          f[:content] ||= Base64.encode64("#{f[:mime_type]}::#{url}").gsub("\n", '')
          f
        end
      end.flatten.compact

      result.each do |r_item|
        #puts r_item
        PluginManager.widgets_for_column(col).each do |widget|
          r_item[:widget] = widget[:name] if [widget[:handle_mime_type]].flatten.include?(r_item[:mime_type])
        end
      end
    end

  end # class
end # module
