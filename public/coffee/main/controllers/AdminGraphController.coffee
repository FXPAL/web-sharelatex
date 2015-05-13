define [
	"base",
	"libs/md5",
	"http://cdn.imnjb.me/libs/sigma.js/1.0.2/sigma.min.js",
	"http://cdn.imnjb.me/libs/sigma.js/1.0.2/plugins/sigma.layout.forceAtlas2.min.js",
	"http://cdn.imnjb.me/libs/sigma.js/1.0.2/plugins/sigma.plugins.dragNodes.min.js"
], (App) ->

	App.controller "AdminGraphController", ($scope, $timeout) ->
		$scope.user = window.data.user
		$scope.user.gravatar =  CryptoJS.MD5($scope.user.email).toString()

		$scope.config = 
			graph: window.data.graph
			container: 'graph'
			settings:
				defaultNodeColor: '#ec5148'

		sigma.renderers.def = sigma.renderers.canvas

		$scope.sGraph = new sigma $scope.config
		$scope.sGraph.startForceAtlas2({worker: true, barnesHutOptimize: false})
		# sigma.plugins.dragNodes($scope.sGraph, $scope.sGraph.renderers[0]);

		$scope.sGraph.refresh()
		
		$timeout () ->
			$scope.sGraph.stopForceAtlas2()
		, 1000