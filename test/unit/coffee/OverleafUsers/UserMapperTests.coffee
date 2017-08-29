should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
path = require('path')
modulePath = path.join __dirname, '../../../../app/js/OverleafUsers/UserMapper'
sinon = require("sinon")
expect = require("chai").expect

describe "UserMapper", ->
	beforeEach ->
		@UserMapper = SandboxedModule.require modulePath, requires:
			"../../../../../app/js/Features/User/UserCreator": @UserCreator = {}
			"../../../../../app/js/models/User": User: @User = {}
			"../../../../../app/js/models/UserStub": UserStub: @UserStub = {}
		@callback = sinon.stub()

	describe "getSlIdFromOlUser", ->
		beforeEach ->
			@ol_user =
				id: "mock-overleaf-id"
				email: "jane@example.com"
			@User.findOne = sinon.stub()
			
		describe "when a user exists already", ->
			beforeEach ->
				@User.findOne.yields(null, @user = { _id: "mock_user_id" })
				@UserMapper.getSlIdFromOlUser @ol_user, @callback

			it "should look up the user by overleaf id", ->
				@User.findOne
					.calledWith({
						"overleaf.id": @ol_user.id
					})
					.should.equal true

			it "should return the user_id", ->
				@callback.calledWith(null, @user._id).should.equal true

		describe "when no user exists", ->
			beforeEach ->
				@User.findOne.yields(null, null)
				@UserStub.update = sinon.stub().yields()
				@UserStub.findOne = sinon.stub().yields(null, @user_stub = { _id: "mock-user-stub-id" })
				@UserMapper.getSlIdFromOlUser @ol_user, @callback

			it "should look up the user by overleaf id", ->
				@User.findOne
					.calledWith({
						"overleaf.id": @ol_user.id
					})
					.should.equal true
			
			it "should ensure the UserStub exists", ->
				@UserStub.update
					.calledWith({
						"overleaf.id": @ol_user.id
					}, { 
						email: @ol_user.email
					}, {
						upsert: true
					})
					.should.equal true

			it "should return the user_id", ->
				@callback.calledWith(null, @user_stub._id).should.equal true

	describe "createSlUser", ->
		beforeEach ->
			@ol_user = {
				id: 42
				email: "jane@example.com"
			}
			@accessToken = "mock-access-token"
			@refreshToken = "mock-refresh-token"
			@UserMapper.getOlUserStub = sinon.stub()
			@UserMapper.removeOlUserStub = sinon.stub().yields()
			@UserCreator.createNewUser = sinon.stub().yields(null, @user = {"mock": "user"})
		
		describe "when a UserStub exists", ->
			beforeEach ->
				@UserMapper.getOlUserStub.yields(null, @user_stub = { _id: "user-stub-id" })
				@UserMapper.createSlUser @ol_user, @accessToken, @refreshToken, @callback
			
			it "should look up the user stub", ->
				@UserMapper.getOlUserStub
					.calledWith(@ol_user.id)
					.should.equal true
			
			it "should create a new user with the same _id", ->
				@UserCreator.createNewUser
					.calledWith({
						_id: @user_stub._id
						email: @ol_user.email
						overleaf: {
							id: @ol_user.id
							accessToken: @accessToken
							refreshToken: @refreshToken
						}
					})
					.should.equal true
			
			it "should remove the user stub", ->
				@UserMapper.removeOlUserStub
					.calledWith(@ol_user.id)
					.should.equal true
			
			it "should return the user", ->
				@callback.calledWith(null, @user).should.equal true
			
		describe "when no UserStub exists", ->
			beforeEach ->
				@UserMapper.getOlUserStub.yields()
				@UserMapper.createSlUser @ol_user, @accessToken, @refreshToken, @callback
			
			it "should create a new user without specifying an id", ->
				@UserCreator.createNewUser
					.calledWith({
						email: @ol_user.email
						overleaf: {
							id: @ol_user.id
							accessToken: @accessToken
							refreshToken: @refreshToken
						}
					})
					.should.equal true
			
			it "should return the user", ->
				@callback.calledWith(null, @user).should.equal true