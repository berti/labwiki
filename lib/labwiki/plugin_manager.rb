require 'omf_base/lobject'
require 'omf_web'
require 'omf-web/theme'

module LabWiki
  module Plugin; end # Put all plugins under this module

  class PluginManager < OMF::Base::LObject
    @@plugins = {}
    @@plugins_for_col = { plan: [], prepare: [], execute: []}

    def self.init
      info "INITIALIZING PLUGINS"
      require 'labwiki/plugin/source_edit/init'
      require 'labwiki/plugin/plan_text/init'

      (LabWiki::Configurator[:plugins] || []).each do |name, opts|
        #puts ">>> #{name} ::: #{opts}"
        if plugin_dir = opts.delete(:plugin_dir)
          lib_dir = File.expand_path(File.join(plugin_dir, 'lib'))
          unless File.readable? lib_dir
            error "Can't find lib directory '#{lib_dir}' for plugin '#{name}'"
            next
          end
          $: << lib_dir
          require "labwiki/plugin/#{name}/init"
        end
      end
    end

    #
    # description:
    #  - widget
    #  - renderer
    #
    def self.register name, description
      info "Loading plugin '#{name}'"
      name = name.to_sym
      if @@plugins[name]
        warn "Plugin '#{name}' is already registered. Overiding previous settings"
      end
      description[:name] = name
      @@plugins[name] = description
      (description[:widgets] || {}).each do |wdescr|
        # :context => :execute,
        # :priority => lambda(),
        # :widget_class => Class
        wdescr[:config_name] ||= name
        if ctxt = @@plugins_for_col[wdescr[:context]]
          ctxt << wdescr
        else
          warn "Ignoring plugin '#{name} for context '#{wdescr[:context]}'"
        end
      end

      # Register provided renderers
      (description[:renderers] || {}).each do |renderer_name, renderer_class|
        OMF::Web::Theme.register_renderer renderer_name, renderer_class, 'labwiki/theme'
      end
    end

    def self.create_widget(column, params)
      debug "Creating widget for '#{column}' from '#{params.inspect}' -- #{@@plugins_for_col[column.to_sym]}"
      if wname = params[:plugin]
        wdescr = plugins_for_column(column).find do |wd|
          puts ">>> #{wname} - #{wd[:name] == wname} - #{wd}"
          wd[:name] == wname
        end
      else
        widget = @@plugins_for_col[column.to_sym].reduce(:priority => 0, :wdescr => {}) do |best, wdescr|
          if priority = wdescr[:priority].call(params)
            if priority > best[:priority]
              best = {:priority => priority, :wdescr => wdescr}
            end
          end
          best
          #mime_type.match(wdescr[:mime_type]) != nil
        end
        wdescr = widget[:wdescr]
      end
      unless wdescr
        raise "Can't find plugin for '#{column}' from '#{params}'"
      end
      unless widget_class = wdescr[:widget_class]
        raise "No execute widget available for '#{params.inspect}'"
      end
      options = Configurator["plugins/#{wdescr[:config_name]}"]
      debug "Creating widget for '#{column}' from '#{widget_class}' (#{options})"
      widget = widget_class.new(column, options, params)
      widget
    end

    def self.plugins_for_column(column)
      @@plugins_for_col[column.to_sym]
    end

    def self.resource_directory_for(plugin_name)
      unless p = @@plugins[plugin_name.to_sym]
        warn "Requesting resource directory for unknown plugin '#{plugin_name}'"
        return nil
      end
      unless rd = p[:resources]
        warn "No resource directory defined for plugin '#{plugin_name}'"
        return nil
      end
      rd
    end

    def self.init_session()
      @@plugins.each do |name, plugin_descr|
        if block = plugin_descr[:on_session_init]
          block.call()
        end
      end
    end

  end # class
end # module

