sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../app/js/AdminController.js"
SandboxedModule = require('sandboxed-module')
events = require "events"
ObjectId = require("mongojs").ObjectId
assert = require("assert")
Path = require "path"

describe "AdminController", ->
	beforeEach ->

		@UserGetter =
			getUser: sinon.stub()

		@UserDeleter =
			deleteUser: sinon.stub().callsArgWith(1)

		@AuthenticationManager =
			setUserPassword: sinon.stub()

		@BetaProgramHandler =
			optIn: sinon.stub().callsArgWith(1, null)
			optOut: sinon.stub().callsArgWith(1, null)

		@AdminController = SandboxedModule.require modulePath, requires:
			"logger-sharelatex":
				log:->
				err:->
			"../../../../app/js/Features/User/UserGetter":@UserGetter
			"../../../../app/js/Features/User/UserDeleter":@UserDeleter
			"../../../../app/js/Features/Authentication/AuthenticationManager":@AuthenticationManager
			"../../../../app/js/infrastructure/mongojs":
				db: @db =
					projects: {}
					users: {}
				ObjectId: ObjectId
			"metrics-sharelatex":
				gauge:->
			"../../../../app/js/Features/BetaProgram/BetaProgramHandler": @BetaProgramHandler

		@user = {user_id:1,first_name:'James'}
		@users = [{first_name:'James'}, {first_name:'Henry'}]
		@projects = [{lastUpdated:1, _id:1, owner_ref: "user-1"}, {lastUpdated:2, _id:2, owner_ref: "user-2"}]
		@perPage = @AdminController.perPage

		@db.users.find = sinon.stub().callsArgWith(3, null, @users)

		@db.users.count = sinon.stub().callsArgWith(1, null, @users.length)

		@db.projects.find = sinon.stub().callsArgWith(2, null, @projects)

		@UserGetter.getUser = (user_id, fields, callback) =>
			callback null, @user

		@req =
			body:
				query: ''

		@res =
			locals:
				jsPath:"js path here"

	describe "listUsers", ->

		it "should render the admin/listUsers page", (done)->
			@res.render = (pageName, opts)=>
				pageName.should.equal  Path.resolve(__dirname + "/../../../")+ "/app/views/listUsers"
				done()
			@AdminController.listUsers @req, @res

		it "should send the users", (done)->
			@res.render = (pageName, opts)=>
				opts.users.should.deep.equal @users
				done()
			@AdminController.listUsers @req, @res

		it "should send the pages", (done)->
			@res.render = (pageName, opts)=>
				opts.pages.should.equal Math.ceil(@users.length / @perPage)
				done()
			@AdminController.listUsers @req, @res

	describe "searchUsers", ->

		beforeEach ->

			@req =
				body:
					query: ''
					page: 1
					sort: 'field_name'
					reverse: true

		it "should send the users", (done)->
			@res.send = (code, json)=>
				code.should.equal 200
				json.users.should.deep.equal @users
				done()
			@AdminController.searchUsers @req, @res

		it "should send the pages", (done)->
			@res.send = (code, json)=>
				code.should.equal 200
				json.pages.should.equal Math.ceil(@users.length / @perPage)
				done()
			@AdminController.searchUsers @req, @res

	describe "getUserInfo", ->

		beforeEach ->

			@req =
				params:
					user_id: 'user_id_here'

		it "should render the admin/userInfo page", (done)->
			@res.render = (pageName, opts)=>
				pageName.should.equal  Path.resolve(__dirname + "/../../../")+ "/app/views/userInfo"
				done()
			@AdminController.getUserInfo @req, @res

		it "should send the user", (done)->
			@res.render = (pageName, opts)=>
				opts.user.should.deep.equal @user
				done()
			@AdminController.getUserInfo @req, @res

		it "should send the user projects", (done)->
			@res.render = (pageName, opts)=>
				opts.projects.should.deep.equal @projects
				done()
			@AdminController.getUserInfo @req, @res

	describe "deleteUser", ->

		it "should delete the user", (done)->
			@req =
				params:
					user_id: 'user_id_here'
			@UserDeleter.deleteUser.calledWith(1)
			@res.sendStatus = (code)=>
				@UserDeleter.deleteUser.calledWith('user_id_here').should.equal true
				code.should.equal 200
				done()
			@AdminController.deleteUser @req, @res

	describe "setUserPassword", ->

		beforeEach ->

			@req =
				body:
					newPassword: 'my great secret password'
				params:
					user_id: 'user_id_here'

		it "should set the user password", (done)->
			@AuthenticationManager.setUserPassword.callsArgWith(2)
			@res.sendStatus = (code)=>
				code.should.equal 200
				done()
			@AdminController.setUserPassword @req, @res

		it "should set the user id", (done)->
			@AuthenticationManager.setUserPassword.callsArgWith(2)
			@res.sendStatus = (code)=>
				@AuthenticationManager.setUserPassword.calledWith('user_id_here', 'my great secret password').should.equal true
				done()
			@AdminController.setUserPassword @req, @res

	describe "setBetaStatus", ->

		beforeEach ->
			@req =
				params:
					user_id: "some_id"
				body: {}

		describe "when beta=true", ->

			beforeEach ->
				@req.body.beta = true

			it "should send a 200 response", (done) ->
				@res.sendStatus = (code)=>
					code.should.equal 200
					done()
				@AdminController.setBetaStatus @req, @res

			it "should call BetaProgramHandler.optIn", (done) ->
				@res.sendStatus = (code)=>
					@BetaProgramHandler.optIn.callCount.should.equal 1
					@BetaProgramHandler.optIn.calledWith('some_id').should.equal true
					done()
				@AdminController.setBetaStatus @req, @res

			it "should not call BetaProgramHandler.optOut", (done) ->
				@res.sendStatus = (code)=>
					@BetaProgramHandler.optOut.callCount.should.equal 0
					done()
				@AdminController.setBetaStatus @req, @res

			describe "when BetaProgramHandler.optIn produces an error", ->

				beforeEach ->
					@BetaProgramHandler.optIn.callsArgWith(1, new Error('woops'))

				it "should send a 500 response", (done) ->
					@res.sendStatus = (code)=>
						code.should.equal 500
						done()
					@AdminController.setBetaStatus @req, @res

		describe "when beta=false", ->

			beforeEach ->
				@req.body.beta = false

			it "should send a 200 response", (done) ->
				@res.sendStatus = (code)=>
					code.should.equal 200
					done()
				@AdminController.setBetaStatus @req, @res

			it "should call BetaProgramHandler.optOut", (done) ->
				@res.sendStatus = (code)=>
					@BetaProgramHandler.optOut.callCount.should.equal 1
					@BetaProgramHandler.optOut.calledWith('some_id').should.equal true
					done()
				@AdminController.setBetaStatus @req, @res

			it "should not call BetaProgramHandler.optIn", (done) ->
				@res.sendStatus = (code)=>
					@BetaProgramHandler.optIn.callCount.should.equal 0
					done()
				@AdminController.setBetaStatus @req, @res

			describe "when BetaProgramHandler.optOut produces an error", ->

				beforeEach ->
					@BetaProgramHandler.optOut.callsArgWith(1, new Error('woops'))

				it "should send a 500 response", (done) ->
					@res.sendStatus = (code)=>
						code.should.equal 500
						done()
					@AdminController.setBetaStatus @req, @res
