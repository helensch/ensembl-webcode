/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2018] EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


Ensembl.Panel.ConfigMatrixForm = Ensembl.Panel.Configurator.extend({
  constructor: function (id, params) {
    this.base(id, params);
    Ensembl.EventManager.remove(id); // Get rid of all the Configurator events which we don't care about
  },
  
  init: function () {
    var panel = this;
    Ensembl.Panel.prototype.init.call(this); // skip the Configurator init - does a load of stuff that isn't needed here

    this.elLk.dx        = {};
    this.elLk.dx.container = $('div#dx-content', this.el);

    this.elLk.dy        = {};
    this.elLk.dy.container = $('div#dy-content', this.el);

    this.elLk.buttonTab       = this.el.find("div.track-tab");
    this.elLk.breadcrumb      = this.el.find("div.large-breadcrumbs li");
    this.elLk.trackPanel      = this.el.find(".track-panel");
    this.elLk.resultBox       = this.el.find(".result-box");
    this.elLk.filterList      = this.el.find("ul.result-list");
    this.elLk.filterButton    = this.el.find("button.filter");
    this.elLk.clearAll        = this.el.find("span.clearall");
    this.localStoreObj        = new Object();
    this.localStorageKey      = 'RegMatrix';
    this.elLk.lookup          = new Object();
    
    this.buttonOriginalWidth = this.elLk.filterButton.outerWidth();
    this.buttonOriginalHTML  = this.elLk.filterButton.html();

    panel.el.find("div#dy-tab div.search-box").hide();

    $.ajax({
      url: '/Json/RegulationData/data?species='+Ensembl.species,
      dataType: 'json',
      context: this,
      success: function(json) {
        this.json = json;
        this.trackTab();
        this.populateLookUp();
        this.loadState();
        this.setDragSelectEvent();
        this.registerRibbonArrowEvents();
        this.updateRHS();
      },
      error: function() {
        this.showError();
      }
    });
    
    this.elLk.buttonTab.on("click", function (e) { 
      panel.toggleTab(this, panel.el.find("div.track-menu"));
      panel.setDragSelectEvent();
    });

    this.elLk.breadcrumb.on("click", function (e) {
      panel.toggleTab(this, panel.el.find("div.large-breadcrumbs"));
      panel.toggleButton();
      e.preventDefault();
      if($(this).hasClass('_configure')) { panel.resetMatrix(); panel.displayMatrix(); }
    });
    
    this.clickSubResultLink();
    this.showHideFilters();
    this.clickCheckbox(this.elLk.filterList, 1);
    this.clearAll(this.elLk.clearAll);
    this.clickFilter(this.elLk.filterButton, this.el.find("li._configure"));
  },

  getActiveTabContainer: function() {
    return $('div#dx-content.active, div#dy-content.active', this.el);
  },
  getActiveTab: function() {
    return $('div#dx-content.active span.rhsection-id, div#dy-content.active span.rhsection-id', this.el).html();
  },
  getActiveSubTab: function() {
    return $('div#dx-content.active .tab-content.active span.rhsection-id, div#dy-content.active .tab-content.active span.rhsection-id', this.el).html();
  },

  populateLookUp: function() {
    var panel = this;
    // cell elements
    this.elLk.dx.ribbonBanner = $('.ribbon-banner .letters-ribbon .alphabet-div', this.elLk.dx.container);
    this.elLk.dx.tabContents = $('.ribbon-content li', this.elLk.dx.container);
    this.elLk.dx.haveSubTabs = false;

    // ExpType elements
    this.elLk.dy.haveSubTabs = true;
    this.elLk.dy.tabs = {}
    this.elLk.dy.tabContents = {};
    var dyTabs = $('.tabs.dy div.track-tab', this.elLk.dy.container);
    $.each(dyTabs, function(i, el) {
      var k = $(el).attr('id').split('-')[0] || $(el).attr('id');
      panel.elLk.dy.tabs[k] = el;
      var tabContentId = $('span.content-id', el).html();
      panel.elLk.dy.tabContents[k] = $('div#' + tabContentId + ' li', panel.elLk.dy.container);
    });
  },

  loadState: function() {
    var panel = this;
    this.loadingState = true;
    this.localStoreObj = this.getLocalStorage();
    if (!Object.keys(this.localStoreObj).length) {
      this.loadingState = false;
      return;
    }

    // Apply cell first so that filter happens and then select all experiment types
    if (this.localStoreObj.dx) {
      var el;
      $.each(this.localStoreObj.dx, function(k) {
        el = panel.elLk.dx.tabContents.not(':not(.'+ k +')');
        panel.selectBox(el);
      });
      panel.filterData($(el).data('item'));
    }
    if (this.localStoreObj.dy) {
      var el, subTab;
      $.each(this.localStoreObj.dy, function(k) {
        subTab = panel.elLk.lookup[k].subTab;
        el = panel.elLk.dy.tabContents[subTab].filter(function() {return $(this).hasClass(k)});
        panel.selectBox(el);
      });

      // If there were no celltypes selected then filter based on exp type
      !this.localStoreObj.dx && this.localStoreObj.dy && panel.filterData($(el).data('item'));
    }

    panel.updateRHS();

    this.loadingState = false;
  },

  setDragSelectEvent: function() {
    var panel = this;
    var zone;

    if (!$('.tab-content.active .tab-content .ribbon-content', panel.el).length) {
      if (this.dragSelect_dx) return;
      zone = '.tab-content.active .ribbon-content';
      this.dragSelect_dx = new Selectables({
        elements: 'ul.letter-content li span',
        // selectedClass: 'selected',
        zone: zone,
        onSelect: function(el) {
          panel.selectBox(el.parentElement, 1);
          this.el = el.parentElement;
        },
        stop: function() {
          panel.filterData($(this.el).data('item'));
          panel.updateRHS();
        }
      });
    }
    else {
      if ($('.tab-content.active .tab-content.active .ribbon-content', panel.el).length) {
        zone = '.tab-content.active .tab-content.active .ribbon-content';
      }
      else {
        zone = '.tab-content.active .tab-content.active';
      }

      if (!$('.tab-content.active .tab-content.active', panel.elLk.trackPanel).length) return;

      if (this.dragSelect_dy && this.dragSelect_dy[this.getActiveSubTab()]) return;
      this.dragSelect_dy = this.dragSelect_dy || {};
      this.dragSelect_dy[this.getActiveSubTab()] = new Selectables({
        elements: 'li span, div.all-box',
        zone: zone,
        // selectedClass: 'selected',
        onSelect: function(el) {
          if($(el).hasClass('all-box')) {
            // Because select-all box is also included in the drag select zone
            // If selected, then trigger its click at the end of the dragSelect event
            // This is because onSelect event is fired on each (LI,DIV) elements
            this.selectAllClick = true;
            this.allBox = el;
          }
          else {
            panel.selectBox(el.parentElement);            
            this.el = el.parentElement;
          }
        },
        stop: function(e) {
          if(this.selectAllClick) {
            $(this.allBox).click();
            this.selectAllClick = false;
          }
          else {
            panel.filterData($(this.el).data('item'));
            panel.updateRHS();
          }
        }
      });      
    }
  },

  //function when click clear all link which should reset all the filters
  clearAll: function (clearLink) {
    var panel = this;
    
    clearLink.on("click",function(e){
      $.each(panel.el.find('div.result-box').find('li').not(".noremove"), function(i, ele){
        panel.selectBox(ele);
      });
    });
    
  },
  
  // Function to check divs that needs to have content to enable or disable apply filter button
  // Argument: ID of div to check for content
  enableConfigureButton: function (content) {
    var panel = this;
    
    var total_div = $(content).length;
    var counter   = 0;

    $(content).each(function(i, el){
      if($(el).find('li').length && $(el).find('span.fancy-checkbox.selected').length) { 
        counter++;
      }
    });

    if(counter === total_div) {
      panel.el.find('button.filter').addClass('active');
      panel.el.find('li._configure').removeClass('inactive');
    } else {
      panel.el.find('button.filter').removeClass('active');
      panel.el.find('li._configure').addClass('inactive');
    }
  },
  
  //function to show/hide error message for empty track filters
  // Argument: containers where to listen for empty elements (Note: span error id should match container id with an underscore)
  trackError: function(containers) {
    var panel = this;

    $(containers).each(function(i, ele) {
        var error_class = "_" + $(ele).attr('id');
        if ($(ele).find('li').length && $(ele).find('span.fancy-checkbox.selected').length) {
            $("span." + error_class).hide();
        } else {
            $("span." + error_class).show();
        }
    });

  },

  // Function to update the current count in the right hand panel (can be adding/removing 1 or select all)
  // Argument: element/container object where current count is to be updated
  //           how much to add to the current value
  updateCurrentCount: function(key, selected, total) {
    var panel = this;
    if(key) {
      $('#'+key+' span.current-count', this.elLk.resultBox).html(selected);
      $('#'+key+' span.total', this.elLk.resultBox).html(total);
    }
  },

  // Function to select/unselect checkbox and removing them from the right hand panel (optional) and adding them to the right hand panel (optional)
  //Argument: container is an object where the checkbox element is
  //        : removeElement either 1 or 0 whether to remove element 
  //        : AddElement is either 1 or 0
  //        : allBox is Object of select all box, check if it needs to be on or off
  clickCheckbox: function (container, removeElement, addElement, allBox) {
    var panel = this;
    var itemListen = "li";
    if(container[0].nodeName === 'DIV') {
      itemListen = "";
    }
    //clicking checkbox
    $(container).off().on("click", itemListen, function(e) {
      panel.selectBox(this);

      if($(this).hasClass('all-box')) {
        if(!$(this).hasClass('no-filter')) {
          var ele = $(this).closest('.tab-content').find('li')[0];
          panel.filterData($(ele).data('item'));
        }
      }
      else {
        panel.filterData($(this).data('item'));
      }
      panel.updateRHS();

      //check whether the select all box is on/off, if it is off and all filters are selected, then make it on and if it is on and all filters are not selected then make it off
      if(allBox && itemListen === "li"){
        if(container.find("span.fancy-checkbox.selected").length === container.find("span.fancy-checkbox").length) {
          allBox.find("span.fancy-checkbox").addClass("selected");
        } else {
          allBox.find("span.fancy-checkbox").removeClass("selected");
        }
      }
      e.stopPropagation();
    });  
  },
  
  updateRHS: function(item) {
    var panel = this;
    panel.updateSelectedTracksPanel(item);
    panel.activateTabs();
    panel.updateShowHideLinks(item);
    panel.setLocalStorage();
    panel.trackError('div#dx, div#dy, div#source');
    panel.enableConfigureButton('div#dx, div#dy, div#source');
  },


  //Function to select filters and adding/removing them in the relevant panel
  selectBox: function(ele) {
    var panel = this;
    var chkbox = $('span.fancy-checkbox', ele);
    var selected = chkbox.hasClass('selected');

    if($(ele).hasClass('all-box')) {
      var _class = '';
      if ($(ele).closest('.tab-content').find('li._filtered').length) {
        _class = "._filtered";
      }

      var available_LIs = $(ele).closest('.tab-content').find('li' + _class + ' span.fancy-checkbox');

      if (!selected) {
        chkbox.addClass('selected');
        // var $(ele).closest('.tab-content').find('li span.fancy-checkbox');
        available_LIs.addClass("selected");
      }
      else {
        chkbox.removeClass('selected')
        available_LIs.removeClass('selected');
      }

      // add 'selected: true/flase' to lookup
      available_LIs.parent().map(function() {
        panel.elLk.lookup[$(this).data('item')].selected = !selected;
      })

    }
    else {

      var item = $(ele).data('item');
      panel.elLk.lookup[item].selected = !selected;

       // Select/deselect elements from LH and RH panels. For that, get the elements from panel.el
      var itemElements = $('.' + item, panel.el);
      if (selected) {
        $(itemElements).find("span.fancy-checkbox").removeClass("selected");
      }
      else {
        $(itemElements).find("span.fancy-checkbox").addClass("selected");
      }


      // Update all-box selected class based on selection
      var lis_unselected = $(itemElements).closest('.tab-content').find('li span.fancy-checkbox').not(".selected");
      var allBox = $(itemElements).closest('.tab-content').find('.all-box span.fancy-checkbox')
      lis_unselected.length ? allBox.removeClass('selected') : allBox.addClass('selected');

    }
  },


  updateSelectedTracksPanel: function(item) {
    var panel = this;
    var selectedElements = [];
    this.selectedTracksCount = {};
    this.totalSelected = 0;
    ['dx', 'dy'].forEach(function(key) {
      var selectedLIs, allLIs;
      if (panel.elLk[key].haveSubTabs) {
        // If tab have subtabs
        $.each(panel.elLk[key].tabContents, function(subTab, lis) {
          selectedLIs = lis.has('.selected') || [];
          allLIs = lis.has('._filtered') || [];
          // In case _filtered class is not applied
          allLIs = allLIs.length || lis.filter(function() { return $(this).css('display') !== 'none' });

          // Storing counts of each tabs - selected and available,  to activate/deactivate tabs and ribbons
          panel.selectedTracksCount[subTab] = panel.selectedTracksCount[subTab] || {};
          panel.selectedTracksCount[subTab].selected = panel.selectedTracksCount[subTab].selected || [];

          $(selectedLIs).map(function(){
            panel.selectedTracksCount[subTab].selected.push($(this).data('item'));
          })
          panel.selectedTracksCount[subTab].available = allLIs.length;
          panel.totalSelected  += selectedLIs.length;

          panel.updateCurrentCount(subTab, selectedLIs.length, allLIs.length);
          selectedLIs.length && selectedElements.push(selectedLIs);
        })
      }
      else {
        selectedLIs = panel.elLk[key].tabContents.has('.selected') || [];
        allLIs = panel.elLk[key].tabContents.has('._filtered') || [];
        allLIs = allLIs.length || panel.elLk[key].tabContents.filter(function() { return $(this).css('display') !== 'none' });

        panel.selectedTracksCount[key] = panel.selectedTracksCount[key] || {};
        panel.selectedTracksCount[key].selected = panel.selectedTracksCount[key].selected || [];
        $(selectedLIs).map(function(){
          panel.selectedTracksCount[key].selected.push($(this).data('item'));
        })
        panel.selectedTracksCount[key].available = allLIs.length;
        panel.totalSelected += selectedLIs.length;

        // update counts
        panel.updateCurrentCount(key, selectedLIs.length, allLIs.length);
        selectedLIs.length && selectedElements.push(selectedLIs);
      }
    });
    // update selected items (cloned checkboxes)
    var clones = {};
    $(selectedElements).each(function(i, arr){
      $(arr).each(function(k, el){
        var k = $(el).data('item');
        clones[k] = $(el).clone().removeClass('noremove');
      });
    });
    panel.updateSelectedTracks(clones);

    // Update store
    var itemKeys = Object.keys(clones);
    !panel.loadingState && panel.addToStore(itemKeys); // Dont add to store while loading state from store
    panel.setLocalStorage();
  },

  // Update selected tracks on the RH panel
  updateSelectedTracks: function (clones) {
    var panel = this;
    // Remove all clones LIs before inserting new ones
    $('li:not(".noremove")', panel.elLk.filterList).remove();

    $.each(clones, function(k, clone) {
      var rhs_id = panel.elLk.lookup[k].subTab;
      $('#'+rhs_id+'.result-content ul', panel.el).append(clone);
    });
  },

  // Enable or disable tabs/ribbons and also show/hide RH panel title
  activateTabs: function() {
    var panel = this;

    $.each(panel.selectedTracksCount, function(key, count) {
      var tab_ele = $('.tabs #' + key + '-tab', panel.el.trackPanel);
      var tab_content_ele = $('#' + key + '-content', panel.el.trackPanel);
      var rhs_ele = $('#'+key, panel.elLk.resultBox);
      if (count.available) {
        tab_ele.removeClass('inactive');
        rhs_ele.show();
      }
      else {
        tab_ele.removeClass('active').addClass('inactive');
        tab_content_ele.removeClass('active');
        rhs_ele.hide();
      }
    });
  },

  setLocalStorage: function() {
    localStorage.setItem(this.localStorageKey, JSON.stringify(this.localStoreObj));
  },
  getLocalStorage: function() {
    return JSON.parse(localStorage.getItem(this.localStorageKey)) || {};
  },

  addToStore: function(items) {
    //Potential fix
    //if(!this.localStoreObj) { this.localStoreObj.matrix = {}; }

    this.localStoreObj = {};
    if (!items.length) return;
    var panel = this;
    var parentTab;

    $.each(items, function(i, item) {
      parentTab = panel.elLk.lookup[item].parentTabId;
      panel.localStoreObj[parentTab] = panel.localStoreObj[parentTab] || {}
      panel.localStoreObj[parentTab][item] = 1;
    });

    panel.localStoreObj.matrix = {};
  },

  removeFromStore: function(item, lhs_section_id) {
    // Removal could happen from RHS or LHS. So section id need to passed as param
    if(lhs_section_id !== 'dx') {
      var tab = 'dy'
      item && lhs_section_id && delete this.localStoreObj[tab][lhs_section_id][item];
    }
    else {
      item && lhs_section_id && delete this.localStoreObj[lhs_section_id][item];
    }
    //TODO need to remove from matrix as well
  },
  
  // Function to show track configuration panel (matrix) when button is clicked
  // Arguments javascript object of the button element and the panel to show
  clickFilter: function(clickButton, tabClick) {
    var panel = this;

    clickButton.on("click", function(e) {
      if(clickButton.hasClass("_edit") ) {
        panel.toggleTab(panel.el.find("li._configure"), panel.el.find("div.large-breadcrumbs"));
        panel.toggleButton();
      } else if(clickButton.hasClass("active") ) {      
        panel.toggleTab(tabClick, panel.el.find("div.large-breadcrumbs"));
        panel.toggleButton();        
      }
      panel.resetMatrix();
      panel.displayMatrix();
    });
  },
  
  //function to jump to tab based on the link
  clickSubResultLink: function() {
    var panel = this;
    panel.el.find('div.sub-result-link').on("click", function(e) {
      var tabId       = "div#" + panel.el.find(this).parent().attr("id") + "-tab";
      var contentId   = "div#" + panel.el.find(tabId).find("span.content-id").html();
      var parentTabId = panel.el.find(this).parent().find("span._parent-tab-id").html();

      panel.el.find(".track-tab.active").first().removeClass("active");
      panel.el.find(".tab-content.active").first().removeClass("active");
      
      //in case the track-content is not active, hide configuration panel first
      if(panel.el.find("div#configuration-content:visible").length){ 
        panel.toggleTab(panel.el.find("li._track-select"), panel.el.find("div.large-breadcrumbs"));
        panel.toggleButton();         
      }

      //for now assuming there is only one parent tab, if there is more than one then we need to create for loop
      if(parentTabId){
        var parentTab       = "div#" + parentTabId;
        var parentContentId = "div#" + panel.el.find(parentTab).find("span.content-id").html();

        panel.el.find(parentContentId+" .track-tab.active").removeClass("active");
        panel.el.find(parentContentId+" .tab-content.active").removeClass("active");
        panel.el.find(parentTab).addClass("active");
        panel.el.find(parentContentId).addClass("active");

        //showing/hiding searchbox in the main tab
        if($(parentTab).find("div.search-box").length) {
          panel.el.find(".search-box").hide();
          $(parentTab).find("div.search-box").show();
        }
      }

      //showing/hiding searchbox in the main tab
      if($(tabId).find("div.search-box").length) {
        panel.el.find(".search-box").hide();
        $(tabId).find("div.search-box").show();
      }

      panel.el.find(tabId).addClass("active");
      panel.el.find(contentId).addClass("active");
    });
  },

  updateShowHideLinks: function() {
      var panel = this;

      $.each(panel.elLk.filterList, function(i, ul) {
        if (!$(ul).siblings("div.show-hide:visible").length && $('li', ul).length) {
          var _class =  $(ul).css('display') === 'none' ? '._show' : '._hide';
          $(ul).siblings(_class).show();
        }
        else if ($(ul).siblings("div.show-hide:visible").length && $('li', ul).length === 0) {
          $(ul).siblings('._hide, ._show').hide();
        }
      })
  },

  //function to toggle filters in right hand panel when show/hide selected is clicked
  showHideFilters: function() {
      var panel = this;

      panel.el.find('div.show-hide').on("click", function(e) {
          panel.el.find(this).parent().find('div.show-hide, ul.result-list').toggle();
      });
  },

  trackTab: function() {
    var panel = this;
    //showing and applying cell types
    var dxContainer = panel.el.find("div#dx-content");
    var rhSectionId = dxContainer.data('rhsection-id');
    var noFilter = true;
    panel.dx = panel.json.dimensions[0];
    panel.dy = panel.json.dimensions[1];
    var dx = panel.json.data[panel.dx];
    var dy = panel.json.data[panel.dy];

    this.displayCheckbox(Object.keys(dx.data).sort(), "div#dx-content", dx.listType, dxContainer, rhSectionId, noFilter);

    //showing experiment type tabs
    var dy_html = '<div class="tabs dy">';
    var content_html    = "";

    //sort dy object
    Object.keys(dy.data).sort().forEach(function(key) {
        var value = dy.data[key];
        delete dy.data[key];
        dy.data[key] = value;
    });

    var count = 0;
    $.each(dy.data, function(key, item){
      var active_class = "";
      if(count === 0) { active_class = "active"; } //TODO: check the first letter that there is data and then add active class
      dy_html += '<div class="track-tab '+active_class+'" id="'+key+'-tab">'+item.name+'<span class="hidden content-id">'+key+'-content</span></div>';
      content_html += '<div id="'+key+'-content" class="tab-content '+active_class+'" data-rhsection-id="'+ key +'""><span class="hidden rhsection-id">'+key+'</span></div>';
      count++;
    });
    dy_html += '</div>';
    var dyContainer = panel.el.find("div#dy-content");
    dyContainer.append(dy_html).append(content_html);
    rhSectionId = dyContainer.data('rhsection-id');
    
    //displaying the experiment types
    if (dy.subtabs) {
      $.each(dy.data, function(key, subTab){
        panel.displayCheckbox(subTab.data, "div#"+key+"-content", subTab.listType, dyContainer, rhSectionId);
      })
    }

    //adding dimension Y and X relationship as data-attribute
    panel.addRelationData();

    //selecting the tab in experiment type
    this.el.find("div.dy div.track-tab").on("click", function () {
      panel.toggleTab(this, panel.el.find("div.dy"));
      panel.setDragSelectEvent();
    });    
    
  },
  
  // Function to toggle tabs and show the corresponding content which can be accessed by #id or .class
  // Arguments: selectElement is the tab that's clicked to be active or the tab that you want to be active (javascript object)
  //            container is the current active tab (javascript object)
  //            selByClass is either 1 or 0 - decide how the selection is made for the container to be active (container accessed by #id or .class)
  toggleTab: function(selectElement, container, selByClass, resetRibbonOffset) {
    var panel = this;

    if(!$(selectElement).hasClass("active") && !$(selectElement).hasClass("inactive")) {
      //showing/hiding searchbox in the main tab
      if($(selectElement).find("div.search-box").length) {
        panel.el.find(".search-box").hide();
        $(selectElement).find("div.search-box").show();
      }

      //remove current active tab and content
      var activeContent = container.find(".active span.content-id").html();
      container.find(".active").removeClass("active");
      if(selByClass) {
        container.find("div."+activeContent).removeClass("active");
      } else {
        panel.el.find("#"+activeContent).removeClass("active");
      }

      //add active class to clicked element
      var spanID = $(selectElement).find("span.content-id").html();
      $(selectElement).addClass("active");

      if(selByClass) {
        activeAlphabetContentDiv = container.find("div."+spanID);
      } else {
        activeAlphabetContentDiv = panel.el.find("#"+spanID);
      }

      activeAlphabetContentDiv.addClass("active");


      // Move to the first available tab if current selected tab has gone inactive after filtering
      var contentId = $('.content-id', selectElement).html();
      var tabs = $('#'+contentId + ' .tabs div.track-tab', panel.elLk.trackPanel);
      if (tabs.length && !tabs.hasClass('active')) {
        if (tabs.not('.inactive').length) {
          var firstActiveTab = tabs.not('.inactive')[0];
          var contentId = $('.content-id', firstActiveTab).html();
          var firstActiveTabContent = $('#'+ contentId, panel.elLk.trackPanel);
          $(firstActiveTab).addClass('active');
          $(firstActiveTabContent).addClass('active');
        }
      }

      if (resetRibbonOffset) {
        $(selectElement).closest('.letters-ribbon').data({'reset': true});
      }

      activeAlphabetContentDiv = panel.elLk.trackPanel.find('div.ribbon-content .alphabet-content.active');
      $.each(activeAlphabetContentDiv, function(i, el) {
        var activeLetterDiv = $(el).closest('.tab-content').find('div.alphabet-div.active');

        // Reset is applied on filterData() if an offset reset is needed for the ribbon
        if ($(activeLetterDiv).closest('.letters-ribbon').data('reset') && $(selectElement).hasClass('track-tab')) {
          var availableAlphabets = panel.getActiveAlphabets();
          var activeAlphabetDiv = availableAlphabets.filter(function(){return $(this).hasClass('active');});
          var activeAlphabetIndex = $(activeLetterDiv).parent().children().index(activeAlphabetDiv);
          var bannerOffset = $(activeLetterDiv).closest('.ribbon-banner').offset();

          // tab containing ribbon need to be visible to get the offset value.
          if ($(activeLetterDiv).closest('.ribbon-banner').closest('.tab-content').css('display') !== 'none') {
            var lettersSkipped = activeAlphabetIndex * 22;
            newOffset =  (bannerOffset.left - lettersSkipped + 10);
            $(activeLetterDiv).closest('.letters-ribbon').offset({left: newOffset});
            // Remove reset once the offset is applied.
            $(activeLetterDiv).closest('.letters-ribbon').removeData('reset');
          }
        }
        // change offset positions of all letter content divs same as their respecitve ribbon letter div
        $(el).offset({left: activeLetterDiv.offset().left - 2});
      })
    }
  },

  toggleButton: function() {
    var panel = this;
    
    if(panel.el.find('div.track-configuration:visible').length){
      panel.el.find('button.view-track').addClass('active');
      panel.el.find('button.filter').addClass("_edit").outerWidth("100px").html("View tracks");
    } else {
      panel.el.find('button.view-track').removeClass('active');
      panel.el.find('button.filter').outerWidth(panel.buttonOriginalWidth).html(panel.buttonOriginalHTML).removeClass("_edit");
    }
  },

  //function to display filters (checkbox label), it can either be inside a letter ribbon or just list
  displayCheckbox: function(data, container, listType, parentTabContainer, parentRhSectionId, noFilter_allBox) {
    var panel       = this;
    var ribbonObj   = {};
    var countFilter  = 0;

    if(listType && listType === "alphabetRibbon") {
      //creating obj with alphabet key (a->[], b->[],...)
      $.each(data, function(j, item) {
        var firstChar = item.charAt(0).toLowerCase();
        if(!ribbonObj[firstChar]) {
          ribbonObj[firstChar] = [];
          ribbonObj[firstChar].push(item);
        } else {
          ribbonObj[firstChar].push(item);
        }
      });
      panel.alphabetRibbon(ribbonObj, container, parentTabContainer, parentRhSectionId, noFilter_allBox);
    } else  {
      var html = '<ul class="letter-content list-content">';
      var rhsection = panel.el.find(container).find('span.rhsection-id').html();

      $.each(data.sort(), function(i, item) {
        if(item) {
          var elementClass = item.replace(/[^\w\-]/g,'_');//this is a unique name and has to be kept unique (used for interaction between RH and LH panel and also for cell and experiment filtering)
          html += '<li class="noremove '+ elementClass + '" data-parent-tab="' + rhsection + '" data-item="' + elementClass +'"><span class="fancy-checkbox"></span><text>'+item+'</text></li>';
        }
        countFilter++;
        panel.elLk.lookup[elementClass] = {
          label: item,
          parentTab: parentTabContainer,
          parentTabId: parentRhSectionId,
          subTab: rhsection,
          selected: false
        };

      });
      html += '</ul>';
      html = '<div class="all-box list-all-box" id="allBox-'+$(container).attr("id")+'"><span class="fancy-checkbox"></span>Select all<text class="_num">('+countFilter+')</text></div>' + html; 
      panel.el.find(container).append(html);
      
      //updating available count in right hand panel
      panel.el.find('div#'+rhsection+' span.total').html(countFilter);

      //clicking select all checkbox
      panel.clickCheckbox(this.el.find(container+" div.all-box"));
    }
  },
  
  //function to add dx and dy in data-filter attribute which link the dx checkbox to the dy checkbox and vice versa, used for filtering to show/hide checkboxes
  addRelationData: function () {
    var panel = this;

    $.each(panel.json.data[panel.dx].data, function(key, dx_data) {
      var dx_className = key.replace(/[^\w\-]/g,'_');

      //add dy attribute to dx
      var relClassNameString="";
      $.each(dx_data, function(index, el) {
        var relClassName = el.val.replace(/[^\w\-]/g,'_');
        relClassNameString += relClassName + " ";
        
        //adding cells atribute to experiments
        var relDataFilter = panel.el.find("li."+relClassName).attr('data-filter');
        relDataFilter ?  panel.el.find("li."+relClassName).attr('data-filter', relDataFilter+" "+dx_className) :  panel.el.find("li."+relClassName).attr('data-filter', dx_className);

        if(!panel.el.find("li."+relClassName).attr('data-filtercontainer')){
          panel.el.find("li."+relClassName).attr('data-filtercontainer', 'dx-content');
        } 
      });
      //data-filter contains the classname that needs to be shown and data-filtercontainer is the id where elements to be shown are located
      panel.el.find("li."+dx_className).attr('data-filter', relClassNameString).attr('data-filtercontainer', 'dy-content');

    });
  },

  // Function that does internal filtering to show/hide other dimension's checkboxes based on a checkbox selection.
  // This will also do the activation/inactivation of tabs based on availability
  // Arguments: selected element item name
  filterData: function(item) {
    var panel = this;

    if (!item) return;

    var tabA_container = $(panel.elLk.lookup[item].parentTab, panel.el);
    var tabB_containerId = '#' + $('.' + item, panel.elLk.trackPanel).data('filtercontainer');
    var tabB_LIs = panel.el.find(tabB_containerId).find('li');

    var filters = {};
    tabA_container.find('li span.fancy-checkbox.selected').parent().map(function(){
      if ($(this).data('filter')) {
        $(this).data('filter').split(' ').map(function(f) {
          if (f!== '') {
            filters[f] = 1;
          }
        });
      }
    })

    // Hide all first and then show based on filters
    tabB_LIs.hide();

    var filters_class = '';
    // Create classees with all filters for selection below
    if (Object.keys(filters).length) {
      filters_class = 'li.' + Object.keys(filters).join(', li.');
      panel.elLk.trackPanel.find(tabB_containerId).find(filters_class).addClass('_filtered').show();

      // Unselect any lis which went hidden after filtering
      tabB_LIs.not('._filtered').find('span.fancy-checkbox').removeClass('selected');
    }
    else {
      // If no filters, then show all LIs in tabB
      tabB_LIs.removeClass('_filtered').show();      
    }

    var resetCount = filters_class === '' ? 1 : 0;

    // Code to activate/deactivate ribbons based on availability
    var mainRHSection = panel.elLk.trackPanel.find(tabB_containerId).find("span.rhsection-id").html();
    // loop for each li to find out where the parent content is and update count
    $.each(panel.elLk.trackPanel.find(tabB_containerId).find('span.rhsection-id'), function(d, tab) {
      var rhsectionId = $(tab).html();
      var newCount    = 0;
      var parentTab   = panel.elLk.trackPanel.find(tab).closest(".tab-content").find("li").data("parent-tab")+"-tab";

      if(panel.el.find("div#"+rhsectionId+".result-content").length) {
        var li_class = resetCount ? "" : "._filtered";  //if resetcount we need to get all li
        $.each(panel.elLk.trackPanel.find(tabB_containerId+' li'+li_class), function(index, elem) {
          if(rhsectionId === $(elem).closest("div.tab-content").find('span.rhsection-id').html()) {
            newCount++;
          } 
        });

        if($(tab).closest(".tab-content").find("div.all-box text._num").length) {
          $(tab).closest(".tab-content").find("div.all-box text._num").html("("+newCount+")");
        }
        if(!newCount) {
          panel.elLk.trackPanel.find("div#"+parentTab).addClass("inactive");
          panel.elLk.trackPanel.find("div#"+rhsectionId+".result-content").hide();
        } else {
          //making sure rhsection is shown and remove inactive class
           panel.elLk.trackPanel.find("div#"+rhsectionId+".result-content").show();
          panel.elLk.trackPanel.find("div#"+parentTab).removeClass("inactive");
        }

        var alphabetContent = $(tab).closest(".tab-content").find("div.ribbon-content div.alphabet-content");
        //if there is alphabet ribbon, going through alphabet ribbon, activating and deactivating the one with/without elements
        if(alphabetContent.length) {
          var setActive = 0; //used to set active ribbon
          var activeCount = 0;
          $(tab).closest(".tab-content").find("div.letters-ribbon div.active").removeClass("active"); //removing existing active first
          $(tab).closest(".tab-content").find("div.alphabet-content.active").removeClass("active");

          $.each(alphabetContent, function(i2, ac_ele) {
            var parentRibbon = $(ac_ele).data("ribbon");

            if($(ac_ele).find("li._filtered").length) {
              activeCount++;
              //toggling tab for first active class adding active class to first alphabet with content in ribbon
              if(!$(tab).closest(".tab-content").find("div.letters-ribbon div.active").length){
                 panel.toggleTab($(tab).closest(".tab-content").find("div."+parentRibbon), $(tab).closest(".tab-content"), 1, 1);
              }
              $(tab).closest(".tab-content").find("div."+parentRibbon).removeClass("inactive"); //remove inactive class in case its present
            } else { //empty

              if($(ac_ele).find("li").length && resetCount) { //resetting everything
                $(tab).closest(".tab-content").find("div."+parentRibbon).removeClass("inactive"); // remove inactive from alphabet ribbon with content 
                $(tab).closest(".tab-content").find("div.rarrow").removeClass("inactive").addClass("active");
                $("div#"+mainRHSection+" div.result-content").show(); //make sure all rhSection link/count are shown

                if(!$(tab).closest(".tab-content").find("div.letters-ribbon div.active").length){
                   panel.toggleTab($(tab).closest(".tab-content").find("div."+parentRibbon), $(tab).closest(".tab-content"), 1, 1);
                }                
              } else { //empty with no li at all
                $(tab).closest(".tab-content").find("div."+parentRibbon).addClass("inactive");
              }
            }
          });

          //disable rarrow and larrow if there is only one ribbon available
          if(activeCount === 1) {
            $(tab).closest(".tab-content").find("div.larrow, div.rarrow").addClass("inactive");
          } else {
            $(tab).closest(".tab-content").find("div.rarrow").addClass("active"); 
          }
        }
      }
    });
  },

  getActiveAlphabets: function(container) {
    var panel = this;
    container = container || this.getActiveTabContainer();
    return $(container).find('.ribbon-banner div.alphabet-div').not('.inactive');
  },

  // Function to create letters ribbon with left and right arrow (< A B C ... >) and add elements alphabetically
  // Arguments: data: obj of the data to be added with obj key being the first letter pointing to array of elements ( a -> [], b->[], c->[])
  //            Container is where to insert the ribbon
  alphabetRibbon: function (data, container, parentTabContainer, parentRhSectionId, noFilter_allBox) {

    var panel = this;
    var html  = "";
    var content_html = "";
    var total_num = 0;
    var rhsection = panel.el.find(container).find('span.rhsection-id').html();

    //generate alphabetical order ribbon (A B C D ....)
    $.each(new Array(26), function(i) {
      var letter = String.fromCharCode(i + 97);
      var active_class = "";
      var letterHTML   = "";
      
      if(i === 0) { active_class = "active"; } //TODO: check the first letter that there is data and then add active class

      if(data[letter] && data[letter].length) {
        letterHTML = '<ul class="letter-content">';
        $.each(data[letter], function(i, el) {
          total_num++;
          var elementClass = el.replace(/[^\w\-]/g,'_');//this is a unique name and has to be kept unique (used for interaction between RH and LH panel and also for cell and experiment filtering)
          letterHTML += '<li class="noremove ' + elementClass + '" data-parent-tab="' + rhsection + '" data-item="' + elementClass + '"><span class="fancy-checkbox"></span><text>'+el+'</text></li>';

          panel.elLk.lookup[elementClass] = {
            label: el,
            parentTab: parentTabContainer,
            parentTabId: parentRhSectionId,
            subTab: rhsection,
            selected: false
          };
        });
        letterHTML += '</ul>';
      } else {
        active_class = "inactive";
      }
      
      html += '<div class="ribbon_'+letter+' alphabet-div '+active_class+'">'+letter.toUpperCase()+'<span class="hidden content-id">'+letter+'_content</span></div>';
      content_html += '<div data-ribbon="ribbon_'+letter+'" class="'+letter+'_content alphabet-content '+active_class+'">'+letterHTML+'</div>';
    });
    var noFilterClass = noFilter_allBox ? 'no-filter' : '';
    panel.el.find(container).append('<div class="all-box '+ noFilterClass +'" id="allBox-'+$(container).attr("id")+'"><span class="fancy-checkbox"></span>Select all<text>(A-Z)</text></div><div class="cell-listing"><div class="ribbon-banner"><div class="larrow inactive">&#x25C0;</div><div class="alpha-wrapper"><div class="letters-ribbon"></div></div><div class="rarrow">&#x25B6;</div></div><div class="ribbon-content"></div></div>');
    panel.el.find(container+' div.letters-ribbon').append(html);
    panel.el.find(container+' div.ribbon-content').append(content_html);

    //updating available count in right hand panel
    panel.el.find('div#'+rhsection+' span.total').html(total_num);
    
    //clicking select all checkbox
    panel.clickCheckbox(this.el.find(container+" div.all-box"));
   
    //clicking the alphabet
    var alphabet = panel.el.find(container+' div.alphabet-div');      
    alphabet.on("click", function(){
      if (!$(container, panel.el).hasClass('active')) {
        return;
      }
      $.when(
        panel.toggleTab(this, panel.el.find(container), 1)
      ).then(
        panel.selectArrow(container)
      );
    });
  },

  selectArrow: function(container) {
    var panel = this;
    var activeAlphabets = panel.getActiveAlphabets(container);
    var startLetter = $(activeAlphabets.get(0)).html().charAt(0);
    var endLetter   = $(activeAlphabets.get(-1)).html().charAt(0);
    if (!activeAlphabets.length) return;

    if($('div.alphabet-div.active', container).html().match(startLetter)) { 
      $('div.larrow', container).removeClass("active").addClass("inactive");
      $('div.rarrow', container).removeClass("inactive").addClass("active"); //just in case jumping from Z to A
    } else if($('div.alphabet-div.active', container).html().match(endLetter)) { 
      $('div.rarrow', container).removeClass("active").addClass("inactive");
      $('div.larrow', container).removeClass("inactive").addClass("active"); //just in case jumping from A to Z
    }else {
      $('div.larrow, div.rarrow', container).removeClass("inactive").addClass("active");
    }
  },

  registerRibbonArrowEvents: function() {
    var panel = this;
    //clicking the left and right arrow
    panel.elLk.arrows   = $('div.rarrow, div.larrow', panel.elLk.trackPanel);
    panel.elLk.arrows.off().on("click", function(e){
      container = $(e.target).closest('.tab-content');
      var ribbonBanner = container.find('.letters-ribbon');
      var ribbonContent = container.find('.ribbon-content');
      var availableAlphabets = panel.getActiveAlphabets(container);
      var activeAlphabetDiv = availableAlphabets.filter(function(){return $(this).hasClass('active');});
      var activeAlphabetIndex = availableAlphabets.index(activeAlphabetDiv);
      var activeAlphabet = activeAlphabetDiv.html().charAt(0).toLowerCase();
      var activeTabId = panel.getActiveTab() + '-tab';

      if (!$(container).hasClass('active') && !$('#' + activeTabId, panel.elLk.trackPanel).hasClass('active')) {
        return; // run only for the active tab
      }

      if(!this.className.match(/inactive/gi)) {
        if(this.className.match(/larrow/gi)) {
          if (!availableAlphabets[activeAlphabetIndex-1]) return;

          //get previous letter 
          var prevLetter = $(availableAlphabets[activeAlphabetIndex-1]).html().charAt(0).toLowerCase();
          // Get total letters skipped to adjust offset (charcode(currentletter - prevLetter))
          var lettersSkipped = activeAlphabet.charCodeAt(0) - prevLetter.charCodeAt(0);

          $.when(
            panel.toggleTab(ribbonBanner.find("div.ribbon_"+prevLetter), container, 1)
          ).then(
            panel.selectArrow(container)
          );

          if(activeAlphabetDiv.offset().left <= $(e.target).offset().left + 22) {
            ribbonBanner.offset({left: ribbonBanner.offset().left + (22 * lettersSkipped)});
            var prevletterContentDiv = ribbonContent.find("div."+prevLetter+"_content.alphabet-content");
            prevletterContentDiv.offset({left: prevletterContentDiv.offset().left + (22 * lettersSkipped)});
          }
        }

        if (this.className.match(/rarrow/gi)) {
          if (!availableAlphabets[activeAlphabetIndex+1]) return;

          var nextLetter = $(availableAlphabets[activeAlphabetIndex+1]).html().charAt(0).toLowerCase();
          // Get total letters skipped to adjust offset (charcode(nextletter-currentletter))
          var lettersSkipped = nextLetter.charCodeAt(0) - activeAlphabet.charCodeAt(0);

          $.when(
            panel.toggleTab(ribbonBanner.find("div.ribbon_"+nextLetter), container, 1)
          ).then(
            panel.selectArrow(container)
          );

          if(activeAlphabetDiv.offset().left  >= $(e.target).offset().left - 44) {
            ribbonBanner.offset({left: ribbonBanner.offset().left - (22 * lettersSkipped)});
            var nextletterContentDiv = ribbonContent.find("div."+nextLetter+"_content.alphabet-content");
            nextletterContentDiv.offset({left: nextletterContentDiv.offset().left - (22 * lettersSkipped)});
          }
        }
      }
      
    });
  },
  
  // Function to show/update/delete matrix
  displayMatrix: function() {
    var panel = this;

    panel.trackPopup = panel.el.find('div.track-popup');

    var xContainer = '<div  class="xContainer">';
    
    //creating array of dy from lookup Obj. ; this will make sure the order is the same
    var dyArray = Object.keys(panel.localStoreObj.dy);

    // State of the column(evidence) or row (cell) which is attached to the labels
    // whether the whole row is on/off, whole column is on/off, render is peak-signal, peak or signal
    // default is on and peak-signal
    // TODO: check if localstore obj matrix exists, if exists get values from localstore Obj else create store
    var rowState, columnState, rowRender, columnRender;

    // creating dy label on top of matrix
    $.each(dyArray, function(i, dyItem){
      var dyLabel = panel.elLk.lookup[dyItem].label;
      if(panel.localStoreObj.matrix[dyItem]) {
        columnState   = panel.localStoreObj.matrix[dyItem].state;
        columnRender  = panel.localStoreObj.matrix[dyItem].render;
      } else {
        columnState   = "track-on";
        columnRender  = "peak-signal";
        panel.localStoreObj.matrix[dyItem] = {"state": columnState, "render": columnRender};
      }
      xContainer += '<div class="xLabel '+dyItem+'" data-track-state="'+columnState+'" data-track-render="'+columnRender+'">'+dyLabel+'</div>';
    });

    xContainer += "</div>";
    panel.el.find('div.matrix-container').append(xContainer);

    //creating cell label with the boxes (number of boxes per row = number of experiments)
    $.each(panel.localStoreObj.dx, function(cellName, value){
        var cellLabel    = panel.elLk.lookup[cellName].label;

        if(panel.localStoreObj.matrix[cellName]) {
          rowState   = panel.localStoreObj.matrix[cellName].state;
          rowRender  = panel.localStoreObj.matrix[cellName].render;
        } else {
          rowState   = "track-on";
          rowRender  = "peak-signal";
          panel.localStoreObj.matrix[cellName] = {"state": rowState, "render": rowRender};
        }        
        var yContainer  = '<div class="yContainer"><div class="yLabel '+cellName+'" data-track-state="'+rowState+'" data-track-render="'+rowRender+'">'+cellLabel+'</div>';
        
        //drawing boxes
        $.each(dyArray, function(i, dyItem) {
          var boxState  = "", boxRender = "";
          var popupType = "peak-signal"; //class of type of popup to use

          //check if there is data or no data with cell and experiment (if experiment exist in cell object then data else no data )
          $.each(panel.json.data[panel.dx].data[cellLabel], function(cellKey, rel){
            if(rel.val.replace(/[^\w\-]/g,'_') === dyItem) {
              var storeKey = dyItem + "_sep_" + cellName; //key for identifying cell is joining experiment(x) and cellname(y) name with _sep_ 
              if(panel.localStoreObj.matrix[storeKey]) {
                boxState   = panel.localStoreObj.matrix[storeKey].state;
                boxRender  = panel.localStoreObj.matrix[storeKey].render;
              } else {
                boxState = "track-on"; //on means blue bg, off means white bg
                boxRender = "peak-signal"; // peak-signal = peak_signal.svg, peak = peak.svg, signal=signal.svg
                panel.localStoreObj.matrix[storeKey] = {"state": columnState, "render": columnRender};
              }              
              return;
            }
          })
          yContainer += '<div class="xBoxes '+boxState+' '+boxRender+' '+cellName+' '+dyItem+'" data-track-x="'+dyItem+'" data-track-y="'+cellName+'" data-box-state="'+boxState+'" data-box-render="'+boxRender+'" data-popup-type="'+popupType+'"></div>';
        });

        yContainer += "</div>";
        panel.el.find('div.matrix-container').append(yContainer);
    });
    panel.cellClick(); //opens popup
    panel.setLocalStorage();
    
    //Hack to close popup
    panel.el.find('button.reset').on("click", function(){
      panel.el.find('div.matrix-container div.xBoxes.track-on, div.matrix-container div.xBoxes.track-off').removeClass("mClick");
      panel.el.find('div.track-popup').hide();
    })
  },

  resetMatrix: function() {
    var panel = this;

    panel.el.find('div.matrix-container').html('');    
    //panel.localStoreObj.matrix = {}; //Empty matrix from localStoreObj when clicking reset
  },

  cellClick: function() {
    var panel = this;

    panel.popupType  = "";
    panel.TrackPopup = "";
    panel.xLabel     = "";
    panel.yLabel     = "";
    panel.xName      = "";
    panel.yName      = "";
    panel.boxObj     = "";

    panel.el.find('div.matrix-container div.xBoxes.track-on, div.matrix-container div.xBoxes.track-off').on("click", function(e){
      panel.el.find('div.matrix-container div.xBoxes.track-on, div.matrix-container div.xBoxes.track-off').removeClass("mClick");
      
      panel.boxObj      = $(this);
      panel.popupType   = $(this).data("popup-type"); //type of popup to use which is associated with the class name
      panel.trackPopup  = panel.el.find('div.track-popup.'+panel.popupType);
      panel.xName       = $(this).data("track-x");
      panel.yName       = $(this).data("track-y");
      panel.xLabel      = $(panel.el.find('div.xLabel.'+panel.xName));
      panel.yLabel      = $(panel.el.find('div.yLabel.'+panel.yName));

      var boxState  = $(this).data("box-state"); //is the track on or off
      var boxRender = $(this).data("box-render"); //is the track peak or signal or peak-signal
      var rowState  = panel.yLabel.data("track-state"); // get the equivalent ylabel first and then its state to determine whether row is on/off
      var rowRender = panel.yLabel.data("track-render"); // renderer of row
      var colState  = panel.xLabel.data("track-state"); // get the equivalent xlabel first and then its state to determine whether column is on/off
      var colRender = panel.xLabel.data("track-render"); // renderer of column       

      $(this).addClass("mClick");
    
      //setting column switch for whether it is on/off
      if(colState === "track-on") {
        panel.trackPopup.find('ul li label.switch input[name="column-switch"]').prop("checked",true);
      } else {
        panel.trackPopup.find('ul li label.switch input[name="column-switch"]').prop("checked",false);
      }

      //setting column radio button for render
      panel.trackPopup.find('ul li input[name=column-radio]._'+colRender).prop("checked",true);

      //setting row switch for whether it is on/off
      if(rowState === "track-on") {
        panel.trackPopup.find('ul li label.switch input[name="row-switch"]').prop("checked",true);
      } else {
        panel.trackPopup.find('ul li label.switch input[name="row-switch"]').prop("checked",false);
      }        

      //setting row radio button for render
      panel.trackPopup.find('ul li input[name=row-radio]._'+rowRender).prop("checked",true);

      //setting box/cell switch on/off
      if(boxState === "track-on") {
        panel.trackPopup.find('ul li label.switch input[name="cell-switch"]').prop("checked",true);
      } else {
        panel.trackPopup.find('ul li label.switch input[name="cell-switch"]').prop("checked",false);
      }

      //setting box/cell radio button for render
      panel.trackPopup.find('ul li input[name=cell-radio]._'+boxRender).prop("checked",true);

      //TODO fix offset of popup when scrolling, it should position based on the mouse click and below
      //center the popup on the box, get the x and y position of the box and then add half the length
      //populating the popup settings (on/off, peak, signals...) based on the data attribute value
      panel.trackPopup.attr("data-track-x",$(this).data("track-x")).attr("data-track-y",$(this).data("track-y")).css({'top':$(this).position().top + 15,'left':$(this).position().left + 15}).show();

      panel.popupFunctionality(); //interaction inside popup
    });
  },

  //function to handle functionalities inside popup (switching off track or changing renderer) and updating state (localstore obj)
  //Argument: Object of the cell/box clicked
  popupFunctionality: function() {
    var panel = this;

    //choosing toggle button - column-switch/row-switch/cell-switch
    //if column is off, set data-track-state to track-off in xLabel, if row is off, set data-track-state to track-off in yLabel, if cell is off set data-track-state to track-off in xBox
    //update localstore obj
    panel.trackPopup.find('ul li label.switch input[type=checkbox]').on("click", function(e) {
      var switchName    = $(this).attr("name");
      var trackState    = $(this).is(":checked") ? "track-on" : "track-off";
      var currentState  = trackState === "track-on"  ? "track-off" : "track-on";    

      if(switchName === "column-switch") {
        panel.xLabel.data("track-state", trackState);
        //panel.xLabel.attr("data-track-state", trackState); //updating the value in the dom
        panel.el.find('div.xBoxes.'+panel.xName+'.'+currentState).data("box-state", trackState).removeClass(currentState).addClass(trackState);//update bg for all cells in the column and also switch cell off
        panel.trackPopup.find('ul li label.switch input[name="cell-switch"]').prop("checked", trackState === "track-on" ? true : false);

        //update localstore
      } else if(switchName === "row-switch") {
        panel.yLabel.data("track-state", trackState);
        //panel.yLabel.attr("data-track-state", trackState); //updating the value in the dom
        panel.el.find('div.xBoxes.'+panel.yName+'.'+currentState).data("box-state", trackState).removeClass(currentState).addClass(trackState);//update bg for all cells in the row and also switch cell off
        panel.trackPopup.find('ul li label.switch input[name="cell-switch"]').prop("checked", trackState === "track-on" ? true : false);
        //TODO: update localstore        
      } else { //cell-switch
        panel.boxObj.data("box-state", trackState);
        //panel.boxObj.attr("data-box-state", trackState); //updating the value in the dom
        panel.boxObj.removeClass(currentState).addClass(trackState);//update bg for all cells in the row
        //TODO: update localstore
        var storeKey = panel.xName+"_sep_"+panel.yName;
        console.log(storeKey);
        panel.localStoreObj.matrix[storeKey].state = trackState;
      }
      panel.setLocalStorage();
    });

    //choosing radio button - track renderer

  }
});
