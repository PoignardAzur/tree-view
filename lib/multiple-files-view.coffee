{CompositeDisposable} = require 'event-kit'

module.exports =
class MultifileView
  constructor: (@path, @prefix, isExpanded) ->
    @subscriptions = new CompositeDisposable()

    @displayedViews = []

    @element = document.createElement('li')
    @element.setAttribute('is', 'tree-view-directory')
    @element.classList.add('directory', 'entry',  'list-nested-item',  'collapsed')

    @header = document.createElement('div')
    @header.classList.add('header', 'list-item')

    @multifilename = document.createElement('span')
    @multifilename.classList.add('name', 'icon')

    @emptyList = document.createElement('ol')
    @emptyList.classList.add('entries', 'list-tree')

    @entries = document.createElement('ol')
    @entries.classList.add('entries', 'list-tree')

    iconClass = 'icon-diff'
    @multifilename.classList.add(iconClass)

    @multifilename.dataset.name = @prefix
    @multifilename.title = @prefix
    @multifilename.textContent = @prefix + '.*'

    @element.appendChild(@header)
    @header.appendChild(@multifilename)
    @element.appendChild(@emptyList)

    @element.draggable = false

    @expand() if isExpanded

    @element.name = @prefix

    @element.collapse = @collapse.bind(this)
    @element.expand = @expand.bind(this)
    @element.toggleExpansion = @toggleExpansion.bind(this)
    @element.isExpanded = @isExpanded

    @element.getPath = @getPath.bind(this)
    @element.isPathEqual = @isPathEqual.bind(this)

    @element.header = @header
    @element.entries = @entries
    @element.multifilename = @multifilename


  addView: (view) ->
    insertionIndex = @displayedViews.findIndex(
      (child) -> view.element.name < child.element.name
    )
    insertionIndex = @displayedViews.length if insertionIndex == -1
    @entries.insertBefore(view.element, @entries.children[insertionIndex] || null)
    @displayedViews.splice(insertionIndex, 0, view)

  removeView: (removedName) ->
    removeIndex = @displayedViews.findIndex(
      (child) -> child.element.name == removedName
    )
    @entries.removeChild(@entries.children[removeIndex])
    @displayedViews.splice(removeIndex, 1)


  lastView: () ->
    return null if @displayedViews.length != 1
    return @displayedViews[0]

  getPath: ->
    @path

  isPathEqual: (pathToCompare) ->
    false

  toggleExpansion: (isRecursive=false) ->
    if @isExpanded then @collapse(isRecursive) else @expand(isRecursive)

  expand: (isRecursive=false) ->
    unless @isExpanded
      @isExpanded = true
      @element.isExpanded = true
      @element.classList.add('expanded')
      @element.classList.remove('collapsed')

      @element.replaceChild(@entries, @emptyList)
    false

  collapse: (isRecursive=false) ->
    if @isExpanded
      @isExpanded = false
      @element.isExpanded = false
      @element.classList.remove('expanded')
      @element.classList.add('collapsed')

      @element.replaceChild(@emptyList, @entries)
