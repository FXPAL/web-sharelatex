/* global _ */

import { Pos } from 'codemirror'
import Fuse from 'fuse.js'

export default function makeAutocomplete (adapter) {
  return function autocomplete (cm) {
    const cursor = cm.getCursor()
    const token = cm.getTokenAt(cursor)

    // Ignore comments or strings
    if (/\b(?:string|comment)\b/.test(token.type)) return
    // Ignore if user removed characters
    if (!token.string.length) return

    const range = cm.getRange(
      Pos(cursor.line, cursor.ch - 1),
      Pos(cursor.line, cursor.ch + 1)
    )
    if (range === ' ' || range === '  ') {
      // If there is a space before or after the cursor then we need to prevent
      // looking back on the line for the previous command

      // Firstly we do this by marking the token as a command
      token.type = 'tag'
      // We also need to remove a backslash from the token string if typing a
      // backslash followed by a space
      token.string = ''
    } else if (token.string === '\\') {
      token.type = 'tag'
    }

    // If there is a previous command on the line, show argument completions.
    // Otherwise show command completions
    const list = adapter.getCompletions(handleCompletionPicked)

    // Fuse seems to have a weird bug where if every item in the list matches
    // equally it picks an item further down the unsorted list, rather than the
    // first of the unsorted list.This appears like the completions are in a
    // weird order when the autocomplete is first opened
    // To work around this, check if the token is a single backslash and show
    // only the unsorted list
    if (token.string === '\\') {
      return {
        list,
        from: Pos(cursor.line, token.start),
        to: Pos(cursor.line, token.end)
      }
    } else {
      try {
        const fuzzySearch = makeFuzzySearch(list)

        return {
          list: fuzzySearch.search(token.string),
          from: Pos(cursor.line, token.start),
          to: Pos(cursor.line, token.end)
        }
      } catch (e) {
        if (e === 'Error: Pattern length is too long') {
          // do nothing
        } else {
          throw e
        }
      }
    }
  }
}

function handleCompletionPicked (cm, autocomplete, completion) {
  // Strip tabstops
  let completionText = completion.text.replace(/\$[0-9]/g, '')

  // If completing \begin also insert \end
  if (isBeginCommand(completionText)) {
    const { line } = cm.getCursor()
    const [whitespace] = cm.getLine(line).match(/^\s*/)

    completionText = `${completionText}\n${whitespace}\n${whitespace}\\end{}`
  }

  cm.replaceRange(
    completionText,
    autocomplete.from,
    autocomplete.to,
    'complete' // Group completion events in undo history
  )

  const firstArg = completionText.match(/[{[]([\w \-_]*)[}\]]/)
  if (firstArg !== null) {
    const lineNo = autocomplete.from.line
    const startPos = {
      line: lineNo,
      ch: autocomplete.from.ch + firstArg.index + 1
    }
    const endPos = {
      line: lineNo,
      ch: startPos.ch + firstArg[1].length
    }
    cm.setSelection(startPos, endPos)
  }
}

function isBeginCommand (completion) {
  return /^\\begin/.test(completion)
}

/*
 * Memoize building up Fuse fuzzy search as it is somewhat expensive
 */
const makeFuzzySearch = _.memoize((list) => {
  return new Fuse(list, {
    threshold: 0.3,
    keys: ['text']
  })
})
