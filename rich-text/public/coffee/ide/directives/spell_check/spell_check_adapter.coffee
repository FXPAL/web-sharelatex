define [], () ->
  class SpellCheckAdapter
    constructor: (@editor) ->
      @wordManager = @editor.wordManager

    getLines: () ->
      @editor.getCodeMirror().getValue().split('\n')

    normalizeChangeEvent: (e) ->
      return {
        start: { row: e.from.line, },
        end: { row: e.to.line },
        action: if e.removed? then 'remove' else 'insert'
      }

    getCoordsFromContextMenuEvent: (e) ->
      e.stopPropagation()
      return {
        x: e.pageX
        y: e.pageY
      }

    preventContextMenuEventDefault: (e) ->
      e.preventDefault()

    getHighlightFromCoords: (coords) ->
      position = @editor.getCodeMirror().coordsChar({
        left: coords.x,
        top: coords.y
      })
      @wordManager.findHighlightAtPosition(position)

    selectHighlightedWord: (highlight) ->
      position = highlight.marker.find()
      # TODO: handle removed markers?
      @editor.getCodeMirror().setSelection(position.from, position.to)

    replaceWord: (highlight, newWord) =>
      codeMirror = @editor.getCodeMirror()
      codeMirror.replaceSelection(newWord)
      codeMirror.focus()
