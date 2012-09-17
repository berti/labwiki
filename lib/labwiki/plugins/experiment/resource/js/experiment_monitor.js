
L.provide('LW.plugin.experiment.experiment_monitor', ['#LW.init'], function () {

  LW.plugin.experiment = {};
  
  LW.plugin.experiment.experiment_monitor = function(exp_name) {
    var current_event = null;
    var graphs = {};
    
    function ctxt() {};
    
    OHUB.bind('data_source.status_' + exp_name + '.changed', function(update) {
      var events = update.events;
    });
    
    
    OHUB.bind('data_source.log_' + exp_name + '.changed', function(update) {
      var events = update.events;
      var l = events.length;
      if (l < 1 || current_event == events[l - 1]) return;
      
      var html = ""
      _.each(events.reverse(), function(e) {
        var ts = e[0].toFixed(1);
        var severity = e[1];
        var message = e[3];
        html = html + '<tr><td>'
          + ts 
          + '</td><td>' + severity
          + '</td><td>' + message
          + '</td></tr>'
          ;          
      });
      $('table.experiment-log').html(html)
    });
    
    OHUB.bind('data_source.graph_' + exp_name + '.changed', function(update) {
      _.each(update.events, function(e) {
        var id = e[0];
        if (graphs[id]) return;
        
        var opts = JSON.parse(e[1]);
        
        
        // Create the datasources
        _.each(opts.data_sources, function(dsh) {
          var ds = OML.data_sources.register(dsh.stream, null, dsh.schema, []);
          if (dsh.update_interval) {
            ds.is_dynamic(dsh.update_interval)
          }
        });
        embed($('div.experiment-graphs'), opts);
      })
    });
        
    var embed = function(embed_container, options) {
      opts = jQuery.extend(true, {}, options); // deep copy
      var type = opts.type;
      
      // Create a div to embed the graph in
      var eid =  'e' + Math.round((Math.random() * 10E12));
      var caption = options.caption || 'Caption Missing';
      var cap_h = '<div class="experiment-graph-caption">'
                //+ '<a href="#" id="d' + id + '" class="ui-draggable">_</a>'
                //+ '<div id="d' + id + '"><img src="/plugin/experiment/img/graph_drag.png"></img></div>'
                + '<img src="/plugin/experiment/img/graph_drag.png" id="d' + eid + '"></img>'
                + '<span class="experiment-graph-caption-figure">Figure:</span>'
                + '<span class="experiment-graph-caption-text">' + caption + '</span>'
                + '</div'
                ;
      embed_container
        .append('<div class="oml_' + type + '" id="w' + eid + '"></div>')
        .append(cap_h)
        ;
      opts.base_el = '#w' + eid;
      L.require('#OML.' + type, 'graph/' + type + '.js', function() {
        //graphs[eid] = new OML[type](opts);
        new OML[type](opts);
      });
        
      // Make Caption draggable
      var del = $('#d' + eid);
      del.data('content', {mime_type: 'data/graph', opts: opts });
      del.data('embedder', function(embed_container) {
        embed(embed_container, options);
      });
      del.draggable({
        appendTo: "body",
        helper: "clone",
        stack: 'body',
        zIndex: 9999
      });
    };
    
    var sections = $('.widget_body h3 a.toggle');
    sections.click(function(ev) {
      var a = $(this)
      a.toggleClass('toggle-closed');
      var p = a.parent().next();
      p.slideToggle(400);
      return false;
    });

    // STOP Experiment button
    $(".btn-stop-experiment").click(function(event) {
      return false; 
    })
        
    return ctxt;
  };
  
 })
