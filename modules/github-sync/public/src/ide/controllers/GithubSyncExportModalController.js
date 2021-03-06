define(['base'], App =>
  App.controller('GithubSyncExportModalController', function(
    $scope,
    $modalInstance,
    $http,
    ide
  ) {
    $scope.cancel = () => $modalInstance.dismiss()

    $scope.status = {
      loading: true,
      error: false
    }

    $scope.form = {
      org: null,
      name: ide.$scope.project.name,
      private: 'false', // String to work with select box model
      description: ''
    }

    $http
      .get('/user/github-sync/orgs', { disableAutoLoginRedirect: true })
      .then(function(response) {
        const { data } = response
        $scope.status.user = data.user
        $scope.status.orgs = data.orgs
        $scope.status.loading = false
        $scope.form.org = $scope.status.user.login
      })
      .catch(function(response) {
        const { data, status } = response
        $scope.status.error = {
          message: data != null ? data.error : undefined,
          statusCode: status
        }
      })

    $scope.create = function() {
      $scope.status.inflight = true
      let data = {
        _csrf: window.csrfToken,
        name: $scope.form.name,
        description: $scope.form.description,
        private: $scope.form.private === 'true'
      }
      // If the user selected themselves as the owner, we
      // don't need to send an org
      if (
        $scope.form.org != null &&
        $scope.form.org !== $scope.status.user.login
      ) {
        data.org = $scope.form.org
      }
      return $http
        .post(`/project/${ide.project_id}/github-sync/export`, data)
        .then(function() {
          $scope.status.inflight = false
          $modalInstance.dismiss()
          return ide.githubSyncManager.openGithubSyncModal()
        })
        .catch(function({ data }) {
          $scope.form.error = data.error
          $scope.status.inflight = false
        })
    }
  }))
