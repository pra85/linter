Path = require 'path'
{CompositeDisposable, Emitter} = require 'atom'
LinterView = require './linter-view'
Bubble = require './bubble'
Panel = require './panel'
PanelView = require './panel-view'
Bottom = require './bottom'
EditorLinter = require './editor-linter'

class Linter

  constructor: ->
    @subscriptions = new CompositeDisposable
    @lintOnFly = true

    @emitter = new Emitter
    @view = new LinterView this
    @bottom = new Bottom this
    @statusBar = null
    @messagesProject = new Map
    @activeEditor = atom.workspace.getActiveTextEditor()
    @editorLinters = new Map
    @linters = []

    if atom.config.get "editor.showErrorInline"
      @bubble = new Bubble this

    atom.config.observe 'linter.showErrorInline', (showErrorInline) =>
      if showErrorInline
        @bubble = new Bubble this
      else
        @bubble?.remove()
        @bubble = null

    @subscriptions.add atom.views.addViewProvider Panel, (model) =>
      @panelView = ( new PanelView() ).initialize(model, @)
    @panel = new Panel this
    @panelModal = atom.workspace.addBottomPanel item: @panel, visible: false

    @subscriptions.add atom.workspace.onDidChangeActivePaneItem (editor) =>
      @activeEditor = editor
      @getLinter(editor)?.lint(false)
      @view.render()
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      currentEditorLinter = new EditorLinter @, editor
      @editorLinters.set editor, currentEditorLinter
      @emitter.emit 'linters-observe', currentEditorLinter
      currentEditorLinter.lint false
      editor.onDidDestroy =>
        currentEditorLinter.destroy()
        @editorLinters.delete currentEditorLinter

  getActiveEditorLinter: ->
    return @getLinter(@activeEditor)

  getLinter: (editor) ->
    return @editorLinters.get editor

  eachLinter: (callback) ->
    values = @editorLinters.values()
    value = values.next()
    while not value.done
      callback(value.value)
      value = values.next()

  observeLinters: (callback) ->
    @eachLinter callback
    @emitter.on 'linters-observe', callback

  deactivate: ->
    @subscriptions.dispose()
    @panel.removeDecorations()
    @bottom.remove()
    @bubble?.remove()
    @eachLinter (linter) ->
      linter.subscriptions.dispose()
    @panelModal.destroy()

module.exports = Linter