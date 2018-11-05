/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
define([
	"base",
	"ace/ace"
], App =>
	App.controller("TestControlsController", $scope =>

		$scope.richText = function() {
			const current = window.location.toString();
			const target = `${current}${window.location.search ? '&' : '?'}rt=true`;
			return window.location.href = target;
		}
	)
);
