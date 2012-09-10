
require 'labwiki/plugins/experiment/renderer/experiment_common_renderer'

module LabWiki::Plugin::Experiment
  
  class ExperimentRunningRenderer < ExperimentCommonRenderer
    
    def render_content
      render_properties
      render_logging
      render_graphs
      
      javascript %{
        L.require('#LW.plugin.experiment.experiment_monitor', '/plugin/experiment/js/experiment_monitor.js', function() {
          #{@widget.datasource_renderer};
          var r_#{object_id} = LW.plugin.experiment.experiment_monitor('#{@widget.name}');
        })
      }
      
    end
    
    
    def render_properties
      properties = @wopts[:properties]
      #puts ">>>> #{properties}"
      render_header "Experiment Properties"
      div :class => 'experiment-status' do
        if properties
          table :class => 'experiment-status table table-bordered', :style => 'width: auto'  do
            render_field_static :name => 'Name', :value => @wopts[:name]
            render_field_static :name => 'Script', :value => @wopts[:url]
            properties.each_with_index do |prop, i|
              prop[:index] = i
              render_field_static(prop, false)
            end
          end
        end
      end
    end
    
    def render_logging
      render_header  "Logging"
      div :class => 'experiment-log' do
        table :class => 'experiment-log table table-bordered'
        #div :class => 'experiment-log-latest'
      end
    end

    def render_graphs
      render_header  "Graphs"
      div :class => 'experiment-graphs' do
      end
    end

    def render_header(header_text)
      h3 do
        a :class => 'toggle', :href => '#'
        text header_text
      end
    end
    
  end # class
end # module