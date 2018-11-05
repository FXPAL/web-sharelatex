/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
define([
	"base"
], function(App) {
	App.controller("BonusLinksController", ($scope, $modal) =>
		$scope.openLinkToUsModal = () =>
			$modal.open({
				templateUrl: "BonusLinkToUsModal",
				controller:  "BonusModalController"
			})
		
);
			
	return App.controller("BonusModalController", ($scope, $modalInstance)=>

		$scope.cancel = () => $modalInstance.dismiss()
	);
});
