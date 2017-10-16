{CompositeDisposable} = require 'event-kit'
Directory = require './directory'
FileView = require './file-view'
File = require './file'
MultifileView = require './multiple-files-view'
{repoForPath} = require './helpers'

module.exports =
class DirectoryView
  constructor: (@directory) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @directory.onDidDestroy => @subscriptions.dispose()

    @displayedViews = []
    @multifileViews = {}
    @_subscribeToDirectory()

    @element = document.createElement('li')
    @element.setAttribute('is', 'tree-view-directory')
    @element.classList.add('directory', 'entry',  'list-nested-item',  'collapsed')

    @header = document.createElement('div')
    @header.classList.add('header', 'list-item')

    @directoryName = document.createElement('span')
    @directoryName.classList.add('name', 'icon')

    @entries = document.createElement('ol')
    @entries.classList.add('entries', 'list-tree')

    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'
      if @directory.isRoot
        iconClass = 'icon-repo' if repoForPath(@directory.path)?.isProjectAtRoot()
      else
        iconClass = 'icon-file-submodule' if @directory.submodule
    @directoryName.classList.add(iconClass)
    @directoryName.dataset.path = @directory.path

    if @directory.squashedNames?
      @directoryName.dataset.name = @directory.squashedNames.join('')
      @directoryName.title = @directory.squashedNames.join('')
      squashedDirectoryNameNode = document.createElement('span')
      squashedDirectoryNameNode.classList.add('squashed-dir')
      squashedDirectoryNameNode.textContent = @directory.squashedNames[0]
      @directoryName.appendChild(squashedDirectoryNameNode)
      @directoryName.appendChild(document.createTextNode(@directory.squashedNames[1]))
    else
      @directoryName.dataset.name = @directory.name
      @directoryName.title = @directory.name
      @directoryName.textContent = @directory.name

    @element.appendChild(@header)
    @header.appendChild(@directoryName)
    @element.appendChild(@entries)

    if @directory.isRoot
      @element.classList.add('project-root')
      @header.classList.add('project-root-header')
    else
      @element.draggable = true
      @subscriptions.add @directory.onDidStatusChange => @updateStatus()
      @updateStatus()

    @expand() if @directory.expansionState.isExpanded

    @element.name = @directory.name

    @element.collapse = @collapse.bind(this)
    @element.expand = @expand.bind(this)
    @element.toggleExpansion = @toggleExpansion.bind(this)
    @element.reload = @reload.bind(this)
    @element.isExpanded = @isExpanded
    @element.updateStatus = @updateStatus.bind(this)
    @element.isPathEqual = @isPathEqual.bind(this)
    @element.getPath = @getPath.bind(this)
    @element.directory = @directory
    @element.header = @header
    @element.entries = @entries
    @element.directoryName = @directoryName

  updateStatus: ->
    @element.classList.remove('status-ignored', 'status-modified', 'status-added')
    @element.classList.add("status-#{@directory.status}") if @directory.status?

  _subscribeToDirectory: ->

    @subscriptions.add @directory.onDidAddEntries (addedEntries) =>
      return unless @isExpanded

      for entry in addedEntries
        if entry instanceof Directory
          @addView(new DirectoryView(entry))
          continue

        prefix = @_getPrefix(entry.name)
        _getPrefix = @_getPrefix

        if multifile = @multifileViews[prefix]
          multifile.addView(new FileView(entry))

        # Find existing file view with same prefix
        else if mergeFile = @displayedViews.find(
          (view) -> _getPrefix(view.element.name) == prefix
        )
          multifile = new MultifileView(@directory.path + '/' + prefix + '.', prefix, true)
          @multifileViews[prefix] = multifile
          @removeView(mergeFile)
          @addView(multifile)
          multifile.addView(new FileView(entry))
          multifile.addView(mergeFile)

        else
          @addView(new FileView(entry))

    @subscriptions.add @directory.onDidRemoveEntries (removedEntries) =>
      for removedName, removedEntry of removedEntries
        unless removedEntry instanceof Directory
          if multifile = @multifileViews[@_getPrefix(removedName)]
            multifile.removeView(removedName)
            if lastView = multifile.lastView()
              @removeView(multifile)
              @addView(lastView)
              delete @multifileViews[@_getPrefix(removedName)]

        if view = @displayedViews.find((view) -> view.element.name == removedName)
          @removeView(view)

  _getPrefix: (name) ->
    i = name.lastIndexOf(".")

    return name if i == -0 || i == -1
    return name.slice(0, i)

  getPath: ->
    @directory.path

  isPathEqual: (pathToCompare) ->
    @directory.isPathEqual(pathToCompare)

  addView: (view) ->
    insertionIndex = @displayedViews.findIndex(
      (child) -> view.element.name < child.element.name
    )
    @entries.insertBefore(view.element, @entries.children[insertionIndex] || null)
    @displayedViews.splice(insertionIndex, 0, view)

  removeView: (view) ->
    @entries.removeChild(view.element)
    @displayedViews.splice(@displayedViews.indexOf(view), 1)

  reload: ->
    @directory.reload() if @isExpanded

  toggleExpansion: (isRecursive=false) ->
    if @isExpanded then @collapse(isRecursive) else @expand(isRecursive)

  expand: (isRecursive=false) ->
    unless @isExpanded
      @isExpanded = true
      @element.isExpanded = @isExpanded
      @element.classList.add('expanded')
      @element.classList.remove('collapsed')
      @directory.expand()

    if isRecursive
      for entry in @entries.children when entry.classList.contains('directory')
        entry.expand(true)

    false

  collapse: (isRecursive=false) ->
    @isExpanded = false
    @element.isExpanded = false

    if isRecursive
      for entry in @entries.children when entry.isExpanded
        entry.collapse(true)

    @element.classList.remove('expanded')
    @element.classList.add('collapsed')
    @directory.collapse()
    @entries.innerHTML = ''
    @displayedViews = []
    @multifileViews = {}
