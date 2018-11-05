define [], () ->
	class CursorPositionManager
		constructor: (@$scope, @adapter, @localStorage) ->
			@$scope.$on 'editorInit', @jumpToPositionInNewDoc

			@$scope.$on 'beforeChangeDocument', @storePositionAndLine

			@$scope.$on 'afterChangeDocument', @jumpToPositionInNewDoc

			@$scope.$on 'changeEditor', @storePositionAndLine

			@$scope.$on "#{@$scope.name}:gotoLine", (e, line, column) =>
				if line?
					setTimeout () =>
						@adapter.gotoLine(line, column)
					, 10 # Hack: Must happen after @gotoStoredPosition
			
			@$scope.$on "#{@$scope.name}:gotoOffset", (e, offset) =>
				if offset?
					setTimeout () =>
						@adapter.gotoOffset(offset)
					, 10 # Hack: Must happen after @gotoStoredPosition

			@$scope.$on "#{@$scope.name}:clearSelection", (e) =>
				@adapter.clearSelection()

		storePositionAndLine: () =>
			@storeCursorPosition()
			@storeFirstVisibleLine()

		jumpToPositionInNewDoc: () =>
			@doc_id = @$scope.sharejsDoc?.doc_id
			setTimeout () =>
				@gotoStoredPosition()
			, 0

		onUnload: () =>
			@storeCursorPosition()
			@storeFirstVisibleLine()

		onCursorChange: () =>
			@emitCursorUpdateEvent()

		onSyncToPdf: () =>
			@$scope.$emit "cursor:#{@$scope.name}:syncToPdf"

		storeFirstVisibleLine: () ->
			if @doc_id?
				docPosition = @localStorage("doc.position.#{@doc_id}") || {}
				docPosition.firstVisibleLine = @adapter.getEditorScrollPosition()
				@localStorage("doc.position.#{@doc_id}", docPosition)

		storeCursorPosition: () ->
			if @doc_id?
				docPosition = @localStorage("doc.position.#{@doc_id}") || {}
				docPosition.cursorPosition = @adapter.getCursor()
				@localStorage("doc.position.#{@doc_id}", docPosition)

		emitCursorUpdateEvent: () ->
			cursor = @adapter.getCursor()
			@$scope.$emit "cursor:#{@$scope.name}:update", cursor

		gotoStoredPosition: () ->
			return if !@doc_id?
			pos = @localStorage("doc.position.#{@doc_id}") || {}
			@adapter.setCursor(pos)
			@adapter.setEditorScrollPosition(pos)
