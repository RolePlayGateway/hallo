#     Hallo - a rich text editing jQuery UI widget
#     (c) 2011 Henri Bergius, IKS Consortium
#     Hallo may be freely distributed under the MIT license
#
#     Image insertion plugin
#     Liip AG: Colin Frei, Reto Ryter, David Buchmann, Fabian Vogler, Bartosz Podlewski
((jQuery) ->
    jQuery.widget "Liip.halloimage",
        options:
            editable: null
            toolbar: null
            uuid: ""
            # number of thumbnails for paging in search results
            limit: 8
            # this function is responsible to fetch search results
            # query: terms to search
            # limit: how many results to show at max
            # offset: offset for the returned result
            # successCallback: function that will be called with the response json object
            #     the object has fields offset (the requested offset), total (total number of results) and assets (list of url and alt text for each image)
            search: null
            searchUrl: null
            # this function is responsible to fetch suggestions for images to insert
            # this could for example be based on tags of the entity or some semantic enhancement, ...
            #
            # tags: tag information - TODO: do not expect that here but get it from context
            # limit: how many results to show at max
            # offset: offset for the returned result
            # successCallback: function that will be called with the response json object
            #     the object has fields offset (the requested offset), total (total number of results) and assets (list of url and alt text for each image)
            suggestions: null
            loaded: null
            upload: null
            uploadUrl: null
            dialogOpts:
                autoOpen: false
                width: 270
                height: "auto"
                title: "Insert Images"
                modal: false
                resizable: false
                draggable: true
                dialogClass: 'halloimage-dialog'
            dialog: null
            buttonCssClass: null
            # Additional configuration options that can be used for
            # image suggestions. The Entity is used to get tags
            # and VIE to load additional data on them.
            entity: null
            vie: null
            dbPediaUrl: "http://dev.iks-project.eu/stanbolfull"
            maxWidth: 250
            maxHeight: 250

        populateToolbar: (toolbar) ->
            widget = this
            dialogId = "#{@options.uuid}-image-dialog"
            @options.dialog = jQuery "<div id=\"#{dialogId}\">
                <div class=\"nav\">
                    <ul class=\"tabs\">
                    </ul>
                    <div id=\"#{@options.uuid}-tab-activeIndicator\" class=\"tab-activeIndicator\" />
                </div>
                <div class=\"dialogcontent\">
            </div>"

            if widget.options.suggestions
                @_addGuiTabSuggestions jQuery(".tabs", @options.dialog), jQuery(".dialogcontent", @options.dialog)
            if widget.options.search or widget.options.searchUrl
                @_addGuiTabSearch jQuery(".tabs", @options.dialog), jQuery(".dialogcontent", @options.dialog)
            if widget.options.upload or widget.options.uploadUrl
                @_addGuiTabUpload jQuery(".tabs", @options.dialog), jQuery(".dialogcontent", @options.dialog)

            @current = jQuery('<div class="currentImage"></div>').halloimagecurrent
                uuid: @options.uuid
                imageWidget: @
                editable: @options.editable
                dialog: @options.dialog
                maxWidth: @options.maxWidth
                maxHeight: @options.maxHeight

            jQuery('.dialogcontent', @options.dialog).append @current

            buttonset = jQuery "<span class=\"#{widget.widgetName}\"></span>"

            id = "#{@options.uuid}-image"
            buttonHolder = jQuery '<span></span>'
            buttonHolder.hallobutton
                label: 'Images'
                icon: 'icon-picture'
                editable: @options.editable
                command: null
                queryState: false
                uuid: @options.uuid
                cssClass: @options.buttonCssClass
            buttonset.append buttonHolder

            @button = buttonHolder
            @button.bind "change", (event) ->
                if widget.options.dialog.dialog "isOpen"
                    widget._closeDialog()
                else
                    widget._openDialog()

            @options.editable.element.bind "hallodeactivated", (event) ->
                widget._closeDialog()

            jQuery(@options.editable.element).delegate "img", "click", (event) ->
                widget._openDialog()

            buttonset.buttonset()
            toolbar.append buttonset

            @options.dialog.dialog(@options.dialogOpts)
            @_handleTabs()

        setCurrent: (image) ->
            @current.halloimagecurrent 'setImage', image

        _handleTabs: ->
            widget = @
            jQuery('.nav li', @options.dialog).bind 'click', ->
                jQuery(".#{widget.widgetName}-tab").hide()
                id = jQuery(this).attr 'id'
                jQuery("##{id}-content").show()
                jQuery("##{widget.options.uuid}-tab-activeIndicator").css("margin-left", jQuery(this).position().left + (jQuery(this).width()/2))
            # Activate first tab
            jQuery('.nav li', @options.dialog).first().click()

        _openDialog: ->
            widget = this
            cleanUp = ->
                window.setTimeout ->
                    thumbnails = jQuery(".imageThumbnail")
                    jQuery(thumbnails).each ->
                        size = jQuery("#" + @id).width()
                        if size <= 20
                            jQuery("#" + @id).parent("li").remove()
                , 15000  # cleanup after 15 sec

            # Update active Image
            jQuery("##{@options.uuid}-sugg-activeImage").attr "src", jQuery("##{@options.uuid}-tab-suggestions-content .imageThumbnailActive").first().attr "src"
            jQuery("##{@options.uuid}-sugg-activeImageBg").attr "src", jQuery("##{@options.uuid}-tab-suggestions-content .imageThumbnailActive").first().attr "src"

            # Save current caret point
            @lastSelection = @options.editable.getSelection()

            # Position correctly
            xposition = jQuery(@options.editable.element).offset().left + jQuery(@options.editable.element).outerWidth() - 3 # 3 is the border width of the contenteditable border
            yposition = jQuery(@options.toolbar).offset().top - jQuery(document).scrollTop() - 29
            @options.dialog.dialog("option", "position", [xposition, yposition])
            # do @_getSuggestions
 
            cleanUp()
            widget.options.loaded = 1

            @options.editable.keepActivated true
            @options.dialog.dialog("open")

            @options.dialog.bind 'dialogclose', =>
              jQuery('label', @button).removeClass 'ui-state-active'
              do @options.editable.element.focus
              @options.editable.keepActivated false

        _closeDialog: ->
            @options.dialog.dialog("close")

        _addGuiTabSuggestions: (tabs, element) ->
            tabs.append jQuery "<li id=\"#{@options.uuid}-tab-upload\" class=\"#{@widgetName}-tabselector #{@widgetName}-tab-upload\"><span>Upload</span></li>"
            tab = jQuery "<div id=\"#{@options.uuid}-tab-upload-content\" class=\"#{@widgetName}-tab tab-upload\"></div>"
            element.append tab

            tab.halloimagesuggestions
                uuid: @options.uuid
                imageWidget: @
                entity: @options.entity

        _addGuiTabSearch: (tabs, element) ->
            widget = this
            dialogId = "#{@options.uuid}-image-dialog"

            tabs.append jQuery "<li id=\"#{@options.uuid}-tab-search\" class=\"#{widget.widgetName}-tabselector #{widget.widgetName}-tab-search\"><span>Search</span></li>"

            tab = jQuery "<div id=\"#{@options.uuid}-tab-search-content\" class=\"#{widget.widgetName}-tab tab-search\"></div>"
            element.append tab

            tab.halloimagesearch
                uuid: @options.uuid
                imageWidget: @
                searchCallback: @options.search
                searchUrl: @options.searchUrl
                limit: @options.limit
                entity: @options.entity

        _addGuiTabUpload: (tabs, element) ->
            tabs.append jQuery "<li id=\"#{@options.uuid}-tab-upload\" class=\"#{@widgetName}-tabselector #{@widgetName}-tab-upload\"><span>Upload</span></li>"
            tab = jQuery "<div id=\"#{@options.uuid}-tab-upload-content\" class=\"#{@widgetName}-tab tab-upload\"></div>"
            element.append tab

            tab.halloimageupload
                uuid: @options.uuid
                uploadCallback: @options.upload
                uploadUrl: @options.uploadUrl
                imageWidget: @
                entity: @options.entity

            ###
            insertImage = () ->
                #This may need to insert an image that does not have the same URL as the preview image, since it may be a different size

                # Check if we have a selection and fall back to @lastSelection otherwise
                try
                    if not widget.options.editable.getSelection()
                        throw new Error "SelectionNotSet"
                catch error
                    widget.options.editable.restoreSelection(widget.lastSelection)

                document.execCommand "insertImage", null, jQuery(this).attr('src')
                img = document.getSelection().anchorNode.firstChild
                jQuery(img).attr "alt", jQuery(".caption").value

                triggerModified = () ->
                    widget.element.trigger "hallomodified"
                window.setTimeout triggerModified, 100
                widget._closeDialog()

            @options.dialog.find(".halloimage-activeImage, ##{widget.options.uuid}-#{widget.widgetName}-addimage").click insertImage
            ###
 )(jQuery)
