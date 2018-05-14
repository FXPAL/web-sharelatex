define [
  'ide/rich-text/directives/cm_editor'
  'ide/rich-text/rich_text_adapter'
  'utils/EventEmitter'
], (cmEditor, RichTextAdapter, EventEmitter) ->
  describe 'cmEditor', () ->
    beforeEach module 'SharelatexApp', ($provide) ->
      $provide.factory 'ide', () ->
        { fileTreeManager: sinon.stub() }
      return

    origRequireJsFn = null
    beforeEach () ->
      origRequireJsFn = window.requirejs
      window.requirejs = @requirejs = sinon.stub()

    afterEach () ->
      window.requirejs = origRequireJsFn

    it 'inits Rich Text', () ->
      editorStub = sinon.stub().returns({
        openDoc: sinon.stub(),
        enable: sinon.stub(),
        getCodeMirror: sinon.stub().returns({
          getValue: sinon.stub().returns('some text'),
          on: sinon.stub(),
          off: sinon.stub(),
          getWrapperElement: sinon.stub().returns({ off: sinon.stub() })
        }),
        disable: sinon.stub()
      })
      @requirejs.callsArgWith(1, Editor: editorStub)
      inject ($compile, $rootScope) ->
        $rootScope.sharejsDoc = stubSharejsDoc()

        $compile('<div cm-editor sharejs-doc="sharejsDoc"></div>')($rootScope)
        $rootScope.$digest()

        expect(editorStub).to.have.been.called

    it 'attaches to CM', () ->
      Editor = stubEditor()

      getCodeMirror = Editor.prototype.getCodeMirror
      openDoc = Editor.prototype.openDoc
      enable = Editor.prototype.enable
      @requirejs.callsArgWith(1, Editor: Editor)
      inject ($compile, $rootScope, $browser) ->
        $rootScope.sharejsDoc = stubSharejsDoc({
          getSnapshot: getSnapshot = sinon.stub().returns(snapshot = {})
          attachToCM: attachToCM = sinon.stub()
        })

        $compile('<div cm-editor sharejs-doc="sharejsDoc"></div>')($rootScope)
        $rootScope.$digest()

        expect(getCodeMirror).to.have.been.called
        expect(getSnapshot).to.have.been.called
        expect(openDoc).to.have.been.called
        expect(openDoc.firstCall.args[0]).to.equal(snapshot)
        expect(attachToCM).to.have.been.called
        expect(enable).to.have.been.called

    it 'calls Editor.update when remoteop event is trigger', () ->
      Editor = stubEditor()
      update = Editor.prototype.update
      @requirejs.callsArgWith(1, Editor: Editor)
      inject ($compile, $rootScope) ->
        $rootScope.sharejsDoc = stubSharejsDoc()
        $compile('<div cm-editor sharejs-doc="sharejsDoc"></div>')($rootScope)
        $rootScope.$digest()

        $rootScope.sharejsDoc.trigger('remoteop')
        expect(update).to.have.been.called

    it 'detaches from CM when destroyed', () ->
      Editor = stubEditor()
      disable = Editor.prototype.disable
      @requirejs.callsArgWith(1, Editor: Editor)
      inject ($compile, $rootScope) ->
        $rootScope.sharejsDoc = stubSharejsDoc({
          detachFromCM: detachFromCM = sinon.stub()
        })

        $compile('<div cm-editor sharejs-doc="sharejsDoc"></div>')($rootScope)
        $rootScope.$digest()
        $rootScope.$broadcast('$destroy')

        expect(detachFromCM).to.have.been.called
        expect(disable).to.have.been.called

  stubCodeMirror = (overrides = {}) ->
    _.extend({
      getValue: sinon.stub().returns('some text'),
      getWrapperElement: sinon.stub().returns({ off: sinon.stub() })
    }, overrides, EventEmitter.prototype)

  stubEditor = () ->
    class Editor
      getCodeMirror: sinon.stub().returns(stubCodeMirror())
      openDoc: sinon.stub()
      enable: sinon.stub()
      disable: sinon.stub()
      update: sinon.stub()

  stubSharejsDoc = (overrides = {}) ->
    _.extend({
      attachToCM: sinon.stub()
      getSnapshot: sinon.stub()
      detachFromCM: sinon.stub()
    }, overrides, EventEmitter.prototype)
