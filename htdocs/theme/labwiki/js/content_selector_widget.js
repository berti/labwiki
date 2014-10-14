
define([], function () {

  /*
   * Each column has a content selection widget which allows the user to select
   * the content to be displayed or edited in this column. The type of content
   * is column specific.
   *
   * The widget itself consists of a text box to type in hints, such as parts of a file
   * name of content and a suggestion list showing a list of potential content candidates
   * as well as previously selected content (history).
   */
  //LW.content_selector_widget = Backbone.Model.extend({
  var content_selector_widget = Backbone.Model.extend({

    initialize: function(column_controller, opts) {
      this._column_controller = column_controller;
      this._opts = opts;
      this._search_pat = '';
      this._content_history = [];
      this._content_recommendations = [];
      this._active = false;

      this._formatters = {
        '_': function(row, i, type, def_formatter) {
               return def_formatter(row.name, row.path, null, i, type);
             }
       };

      var self = this;
      OHUB.bind('data_source.content_choices_' + OML.session_id + '.changed', function(evt) {
        console.log('active', self._active);
        if (! self._active) return;

        var rows = evt.data_source.rows();
        var list = _.map(rows, function(row) {
          var j = row[2];
          return JSON.parse(j);
        })
        self._content_recommendations = list;
        self._refresh_suggestion_list(list);
      });
    },

    /*
     * Each column has a search box at the top to allow the selection of the content
     * to be displayed. This method attaches all kind of functionality to the various
     * form elements making up the search box. All these elements have an id starting
     * with 'el_prefix'.
     */
    init: function(el_prefix, opts) {
      this._opts = opts;
      var self = this;
      //var si = $('#' + el_prefix + '_si');
      var context_el = this._context_el = $('#' + el_prefix + '_search');
      var si = this._input_el = context_el.find('.input');

      si.bind('keyup click focus', function(ev) {
        return self._process_input(ev, si);
      });

      si.bind('focus', function() {
        self._active = true;
        self._refresh_suggestion_list();
        context_el.find('.suggestion-list').css('overflow', 'auto').show();
        return false;
      });
      si.bind('blur', function() {
        self._active = false;
        context_el.find('.suggestion-list').delay(200).slideUp(200); //hide();
        return false;
      });

      // What's that'
      context_el.find('.reset').click(function(ev) {
        self.reset();
        //si.delay(100).focus(); // doesn't work'
        return true;
      });

      this._init_suggestion_lists(context_el);
    },

    set_search_list_formatter: function(widget_name, formatter_f) {
      this._formatters[widget_name] = formatter_f;
    },

    add_tool: function(name, html_frag) {
      var context_el = this._context_el;
      var tools_list = context_el.find('.tools-list');
      var tools_ul = tools_list.find('ul');
      tools_ul.append('<li class="tool-name">' + name + '</li>');
      tools_ul.append('<li class="tool-menu-item">' + html_frag + '</li>');

      // Fist time around make tool button visible and attach interaction handlers
      var ab = context_el.find('.action-buttons');
      if (! ab.is(':visible')){
        ab.show();
        var tb = ab.find('.tool-button');
        tb.bind('click', function(ev) {
          if (tools_list.is(':visible')) {
            tools_list.delay(200).slideUp(200);
          } else {
            tools_list.show();
          }
        });
        tb.bind('blur', function(ev) {
          if (tools_list.has(ev.relatedTarget).length == 0) {
            tools_list.delay(200).slideUp(200);
          }
        });
      }
    },


    // Reset the search pattern
    //
    reset: function() {
      if (this._input_el) {
        this._input_el.val('');
      }
    },

    // Load content into associated column
    //
    load_content: function(content_descr) {
      var ch = this._content_history;
      ch.splice(0, 0, content_descr);
      ch = _.uniq(ch);
      ch.splice(5, 99); // only keep 5 latest
      this._content_history = ch;

      this._context_el.find('.suggestion-list').hide(); // make it go away fast so I know how much space I need for widget
      this.reset(); // clear text box

      console.log("LOAD: " + content_descr.label);
      this._column_controller.load_content(content_descr);
    },

    _process_input: function(ev, input_el) {
      switch (ev.keyCode) {
        case 13: {
          input_el.blur(); // try to loose focus - doesn't seem to work, though
          if (this._selected_suggestion_li) {
            var el = this._selected_suggestion_li.find('a');
            this._load_from_el(el);
            return true;
          }
          var ct = this._content_recommendations[0];
          if (ct) {
            this.load_content(ct);
          }
          return true;
        }
        case 38: { // cursor UP
          this._process_up_arrow(this._context_el.find('ul.suggestion-list'));
          return true;
        }
        case 40: { // cursor DOWN
          this._process_down_arrow(this._context_el.find('ul.suggestion-list'));
          return true;
        }
        default: {
          var pat = input_el.val();
          if (this._search_pat != pat) {
            this._query(pat);
          }
          this._search_pat = pat;
        }
      }
      return false;
    },

    _query: function(pat) {
      var self = this;
      var opts = this._opts;
      var data = {'id': opts.sid, 'col': opts.col, 'pat': pat};
      $.ajax({
        url: '_search',
        data: data,
        type: 'get',
        dataType: 'json'
      }).done(function(reply) {
        // now comes through data_source
//        if (reply.result) {
//          var list = reply.result;
//          self._content_recommendations = list;
//          self._refresh_suggestion_list(list);
//        } else if (reply.retry) {
//          // Retry again later
//          setTimeout(function() {
//            if (self._search_pat == pat) {
//              // Still loking for the same pattern
//              self._query(pat);
//            }
//          }, 1000);
//        }
      }).fail(function(xhr) {
        if (xhr.status == 401) {
          // Server lost authentication information and requires a new login
          // Should really be done through a popup informing what's going on
          window.location.reload();
        } else {
          alert("Server is sending error message I don't understand");
        }

      });

    },

    _process_up_arrow: function(list) {
      var li_sel = null;
      var li_curr = this._selected_suggestion_li;
      if (li_curr) {
        var prev = li_curr.prev();
        if (prev.length > 0){
          li_sel = prev;
        }
      }
      if (!li_sel) {
        var list_li = list.find('li');
        li_sel = list_li.last();
      }
      this._select_suggestion(li_sel);
    },

    _process_down_arrow: function(list) {
      var li_sel = null;
      var li_curr = this._selected_suggestion_li;
      if (li_curr) {
        var next = li_curr.next();
        if (next.length > 0){
          li_sel = next;
        }
      }
      if (!li_sel) {
        var list_li = list.find('li');
        li_sel = list_li.eq(0);
      }
      this._select_suggestion(li_sel);
    },

    _init_suggestion_lists: function(context_el) {
      var self = this;
      // Handle mouse hover over suggestion list
      context_el.find('ul.suggestion-list li').hover(function(ev) {
        self._select_suggestion($(this));
        return true;
      }, function(ev) {
        self._select_suggestion(null);
        return false;
      });
      // Handle someone clicking on suggestion list
      context_el.find('ul.suggestion-list a').click(function(ev) {
        self._load_from_el($(this));
        return true;
      });

    },

    // Extract the information on what content to load from the attributes
    // of 'el' - it is supposed to be an <a> element.
    _load_from_el: function(el) {
      var id = el.attr('lw:id');
      var type = el.attr('lw:type');
      var list = type == 'rec' ? this._content_recommendations : this._content_history;
      this.load_content(list[id]);
    },

    _select_suggestion: function(li_el) {
      var li_sel = this._selected_suggestion_li;
      if (li_sel == li_el) return;

      if (li_sel) {
        li_sel.removeClass('ui-menu-item-selected');
      }
      if (li_el) {
        li_el.addClass('ui-menu-item-selected');
      }
      this._selected_suggestion_li = li_el;
    },

    _refresh_suggestion_list: function() {
      var ul = this._context_el.find('ul.suggestion-list');
      ul.find('li').remove();
      rec_li = this._build_suggestion_list(this._content_recommendations, 'rec');
      hist_li = this._build_suggestion_list(this._content_history, 'hist');
      $(rec_li + hist_li).appendTo(ul);
      this._init_suggestion_lists(this._context_el);
    },

    def_formatter_template: "<li class='{klass}'>\
      <a class='ui-corner-index' lw:id='{idx}' lw:type='{type}'>\
        <div class='image'><img src='/resource/{img_url}'></img></div>\
        <div class='t'>\
          <div class='title'>{title}</div>\
          <div class='sub_title'>{sub_title}</div>\
        </div>\
      </a></li>",

    _build_suggestion_list: function(slist, type) {
      var formatters = this._formatters;
      var self = this;
      var defFormatter = function (title, sub_title, img_url, index, type) {
        var klass = 'ui-menu-item';
        if (img_url == null) {
          img_url = "theme/labwiki/images/file-16.png";
        }
        //if (i == 0) klass = klass + ' ui-menu-item-first ui-menu-item-first-' + type;
        var c = {klass: klass, idx: "" + index, type: type, img_url: img_url, title: title, sub_title: sub_title};
        var h = self.def_formatter_template.replace(/{[^{}]+}/g, function(key) {
          return c[key.replace(/[{}]+/g, "")] || "";
        });
        return h;
      };
      var lia = slist.map(function(row, i) {
        var f = formatters[row.widget] || formatters['_'];
        return f(row, i, type, defFormatter);
      });
      var li = lia.join('');
      return li;
    },

    init2: function(el_prefix, opts) {
      this._opts = opts;
      var self = this;
      var si = $('#' + el_prefix + '_si');
      var panel = $('#col_content_' + self._name + ' .panel-body');

      $('#' + el_prefix + '_hi a').hover(
        function() {$(this).addClass('ui-state-hover');},
        function() {$(this).removeClass('ui-state-hover');}
      );
      $('#' + el_prefix + '_hi a').click(function() {
        si.autocomplete("close");
        $('#' + el_prefix + '_hi ul').hide();
        var content = $(this).attr('lw:content');
        self.load_content({content: content});
        return false;
      }),

      si.autocomplete({
        source: '_search?sid=' + opts.sid + '&col=' + opts.col,
        appendTo: $('#' + el_prefix + '_sl'),
        //autoFocus: true,
        minLength: 0,
        open: function() {
          console.log('OPEN');
          var w = si.autocomplete("widget");
          w.css('left', '0px');
          w.css('top', '0px');
          var i = 0;
        },
        close: function() {
          //$('this').element.val(''); // clear search box
          // TODO: This is a bit of a hack and leads to the menu blinking
          // as the search box is getting back focus when the menu is clicked on.
          //si.autocomplete("close").blur();
          $('#' + el_prefix + '_hi ul').hide();
          panel.focus();
          console.log('CLOSE');
        },
        select: function(event, ui) {
          //$('#' + el_prefix + '_si').autocomplete("close");
          //$('.summary').focus();
          //si.autocomplete("close");
          self.load_content(ui.item.value, {});
          return false;
        }
      });

      $('#' + el_prefix + '_si').focus(function () {
        //console.log('FOCUS');
        $('#' + el_prefix + '_hi ul').show();
        $('#' + el_prefix + '_si').autocomplete("search");
        //return true;
      });
    },

  });

  return content_selector_widget;
});
