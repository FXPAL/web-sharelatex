/* eslint-disable
    max-len,
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
  'ide/rich-text/controllers/editor_loader_controller',
  'utils/EventEmitter'
], (EditorLoaderController, EventEmitter) =>
  describe('EditorLoaderController', function() {
    beforeEach(module('SharelatexApp'))

    let origRequireJsFn = null
    beforeEach(function() {
      origRequireJsFn = window.requirejs
      return (window.requirejs = this.requirejs = sinon.stub())
    })

    afterEach(() => (window.requirejs = origRequireJsFn))

    it('inits richText scope', () =>
      inject(($rootScope, $controller) => {
        const $scope = $rootScope.$new()
        $controller('EditorLoaderController', { $scope })

        expect($scope.richText.bundle).to.equal(null)
        return expect($scope.richText.formattingEvents).to.be.an.instanceof(
          EventEmitter
        )
      }))

    it('watches showRichText and loads bundle if true', function() {
      return inject(($rootScope, $controller) => {
        const $scope = $rootScope.$new()
        $scope.editor = { showRichText: false }

        expect(this.requirejs).to.not.have.been.called

        $controller('EditorLoaderController', { $scope })

        $scope.editor.showRichText = true
        $rootScope.$digest()

        return expect(this.requirejs).to.have.been.called
      })
    })

    return it('watches showRichText and does nothing if false', function() {
      return inject(($rootScope, $controller) => {
        const $scope = $rootScope.$new()
        $scope.editor = { showRichText: true }

        $controller('EditorLoaderController', { $scope })

        $scope.editor.showRichText = false
        $rootScope.$digest()

        return expect(this.requirejs).to.not.have.been.called
      })
    })
  }))
