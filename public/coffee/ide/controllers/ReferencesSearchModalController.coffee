define [
	"base"
], (App) ->
	App.controller "ReferencesSearchModalController", ($scope, $modalInstance, $http, $window, $timeout, ide) ->

		$scope.setup = () ->
			console.log ">> setup key stuff"
			domElements = {}
			domElements.modal = document.querySelector('.references-search-modal')
			domElements.input = domElements.modal.querySelector('input.query-text')
			domElements.hiddenInput = domElements.modal.querySelector('input.hidden')

			$scope.domElements = domElements

		$scope.state =
			queryText: ""
			searchResults: null
			selectedIndex: null
			currentlySearching: false

		$scope.moveSelectionForward = () ->
			# if document.activeElement == $scope.domElements.input
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
			# if document.activeElement == $scope.domElements.input
			if $scope.state.selectedIndex == null
				# do nothing
				return
			else
				if $scope.state.searchResults && $scope.state.searchResults.length > 0
					$scope.state.selectedIndex--
					if $scope.state.selectedIndex < 0
						$scope.state.selectedIndex = null

		$scope.handleInputKeyDown = (e) ->
			if e.keyCode == 40  # down
				e.preventDefault()
				$scope.moveSelectionForward()
				return

			if e.keyCode == 38  # up
				e.preventDefault()
				$scope.moveSelectionBackward()
				return

			if e.keyCode == 9  # tab
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

		$scope.doSearch = () ->
			console.log ">> doing search"
			opts =
				query: $scope.state.queryText
				_csrf: window.csrfToken
			$scope.state.currentlySearching = true
			$.post(
				"/project/#{$scope.project_id}/references/search",
				opts,
				(data) ->
					console.log data
					$scope.state.searchResults = data.hits
					$scope.state.selectedIndex = null
					$scope.state.currentlySearching = false
					$scope.$digest()
			)
			# stop searching state after 30 seconds
			$timeout(
				() ->
					$scope.state.currentlySearching = false
				, 30000
			)

		$scope.selectItem = () ->

		$scope.acceptSelectedSearchResult = () ->
			console.log ">> accept search result #{$scope.state.selectedIndex}"

		$scope.cancel = () ->
			$modalInstance.dismiss('cancel')
