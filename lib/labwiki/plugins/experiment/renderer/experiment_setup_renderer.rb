
require 'labwiki/plugins/experiment/renderer/experiment_common_renderer'

module LabWiki::Plugin::Experiment

  class ExperimentSetupRenderer < ExperimentCommonRenderer

    def render_content
      render_start_form
    end

    def render_start_form
      fid = "f#{self.object_id}"
      properties = @experiment.properties
      #puts "EXP: #{@experiment}--#{properties}"
      form :id => fid, :class => 'start-form' do
        if properties
          table :class => 'experiment-setup', :style => 'width: auto' do
            render_field -1, :name => 'Name', :size => 24, :default => @experiment.name
            render_field(-1, name: 'Experiment', type: :select, options: OMF::Web::SessionStore[:exps, :gimi].map {|v| v['name']}) if OMF::Web::SessionStore[:exps, :gimi]
            render_field(-1, name: 'Slice', type: :text, default: "default_slice")

            render_field_static :name => 'Script', :value => @experiment.url
            properties.each_with_index do |prop, i|
              render_field(i, prop)
            end
            tr :class => "buttons" do
              td :colspan => 3 do
                input :type => "hidden", :name => "name1",  :id => "id1", :value => "value1"
                button "Start Experiment", :class => 'btn btn-primary', :type => "submit", :id => "id_startExperiment"
                # input :id => "id_startExperiment", :name => "name_startExperient", :class => "submit button-text btn",
                  # :type => "submit", :value => "Start Experiment"
                  #:onmousedown => "doSubmitEvents();"
              end
            end
          end
        end
        render_javascript(fid)
      end

    end

    def render_javascript(fid)
      opts = {
        :properties => @experiment.properties,
        :widget_id => @widget.widget_id,
        :url => "lw:execute/experiment?url=#{@experiment.url}",
        :script => @experiment.url
      }
      javascript %{
        $("\##{fid}").submit(function(event) {
          event.preventDefault();

          var form_el = $(this);
          var fopts = #{opts.to_json};
          var ec = $("\##{@data_id}").data('ec');
          ec.submit(form_el, fopts);
        });
      }
    end

    def render_properties
      properties = @experiment.properties
      #puts ">>>> #{properties}"
      div :class => 'experiment-status' do
        if properties
          table :class => 'experiment-status', :style => 'width: auto'  do
            render_field_static :name => 'Name', :value => @experiment.name
            render_field_static :name => 'Script', :value => @experiment.url
            properties.each_with_index do |prop, i|
              prop[:index] = i
              render_field_static(prop)
            end
          end
        end
      end
    end


  end # class
end # module
