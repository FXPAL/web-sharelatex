/* eslint-disable
    no-return-assign,
    no-undef,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
define([
	"base"
], App =>
	App.controller("GithubSyncUnlinkController", ($scope, $modal) =>
		$scope.unlinkAccount = () =>
			$modal.open({
				templateUrl: "githubSyncUnlinkModalTemplate"
			})
		
	)
);