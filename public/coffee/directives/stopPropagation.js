/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
define([
	"base"
], function(App) {
	App.directive("stopPropagation", $http =>
		({
			restrict: "A",
			link(scope, element, attrs) {
				return element.bind(attrs.stopPropagation, e => e.stopPropagation());
			}
		})
);

	return App.directive("preventDefault", $http =>
		({
			restrict: "A",
			link(scope, element, attrs) {
				return element.bind(attrs.preventDefault, e => e.preventDefault());
			}
		})
);
});
