define [
	"base"
], (App) ->
	App.controller "ReferencesSearchModalController", ($scope, $modalInstance, $window, $timeout, ide) ->

		$scope.state =
			queryText: ""
			searchResults: null
			selectedIndex: null
			currentlySearching: false
			errorMessage: null

		$scope.handleInputKeyDown = (e) ->
			if e.keyCode == 40  # down
				e.preventDefault()
				$scope.moveSelectionForward()
				return

			if e.keyCode == 38  # up
				e.preventDefault()
				$scope.moveSelectionBackward()
				return

			if e.keyCode == 9  # tab & shift-tab
				e.preventDefault()
				if e.shiftKey
					$scope.moveSelectionBackward()
				else
					$scope.moveSelectionForward()
				return

			if e.keyCode == 13  # enter
				e.preventDefault()
				$scope.acceptSelectedSearchResult()
				return

			if e.keyCode in [8, 37, 39]  # backspace, left and right
				$scope.state.selectedIndex = null
				return

			if e.keyCode == 16  # shift-key alone
				return

			# for all other key strokes
			# do autosearch in next cycle
			$timeout $scope.doAutoSearch, 0
			return

		$scope.doAutoSearch = () ->
			state = $scope.state
			if !state.currentlySearching
				if state.queryText && state.queryText.length >= 3
					$scope.doSearch()

		$scope.moveSelectionForward = () ->
			if $scope.state.selectedIndex == null
				if $scope.state.searchResults && $scope.state.searchResults.length > 0
					$scope.state.selectedIndex = 0
			else
				if $scope.state.searchResults && $scope.state.searchResults.length > 0
					$scope.state.selectedIndex++
					lastIndex = $scope.state.searchResults.length - 1
					if $scope.state.selectedIndex > lastIndex
						$scope.state.selectedIndex = lastIndex

		$scope.moveSelectionBackward = () ->
			if $scope.state.selectedIndex == null
				# do nothing
				return
			else
				if $scope.state.searchResults && $scope.state.searchResults.length > 0
					$scope.state.selectedIndex--
					if $scope.state.selectedIndex < 0
						$scope.state.selectedIndex = null

		$scope.doSearch = () ->
			if $scope.state.queryText == ''
				return
			opts =
				query: $scope.state.queryText
				_csrf: window.csrfToken
			$scope.state.currentlySearching = true
			ide.$http.post("/project/#{$scope.project_id}/references/search", {
				query: $scope.state.queryText
				_csrf: window.csrfToken
			}).then(
				(successResponse) ->
					$scope.state.searchResults = successResponse.data.hits
					$scope.state.selectedIndex = null
					$scope.state.currentlySearching = false
					$scope.state.errorMessage = null
				(errorResponse) ->
					console.error ">> error searching references", errorResponse
					$scope.state.selectedIndex = null
					$scope.state.currentlySearching = false
					$scope.state.errorMessage = "something's gone wrong :("
			)

			# stop searching state after 30 seconds
			$timeout(
				() ->
					$scope.state.currentlySearching = false
				, 30000
			)

		$scope.selectIndex = (index) ->
			if $scope.state.searchResults
				$scope.state.selectedIndex = index

		$scope.acceptSelectedSearchResult = () ->
			if $scope.state.searchResults && $scope.state.selectedIndex != null
				result = $scope.state.searchResults[$scope.state.selectedIndex]
				$modalInstance.close(result.EntryKey)

		$scope.cancel = () ->
			$modalInstance.dismiss('cancel')
