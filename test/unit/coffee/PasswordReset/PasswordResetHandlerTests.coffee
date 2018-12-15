should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
path = require('path')
sinon = require('sinon')
modulePath = path.join __dirname, "../../../../app/js/Features/PasswordReset/PasswordResetHandler"
expect = require("chai").expect

describe "PasswordResetHandler", ->

	beforeEach ->

		@settings = 
			siteUrl: "www.sharelatex.com"
		@OneTimeTokenHandler =
			getNewToken:sinon.stub()
			getValueFromTokenAndExpire:sinon.stub()
		@UserGetter =
			getUserByMainEmail:sinon.stub()
			getUser: sinon.stub()
		@EmailHandler = 
			sendEmail:sinon.stub()
		@AuthenticationManager =
			setUserPasswordInV1:sinon.stub()
			setUserPasswordInV2:sinon.stub()
		@V1Api =
			request: sinon.stub()
		@PasswordResetHandler = SandboxedModule.require modulePath, requires:
			"../User/UserGetter": @UserGetter
			"../Security/OneTimeTokenHandler": @OneTimeTokenHandler
			"../Email/EmailHandler":@EmailHandler
			"../Authentication/AuthenticationManager":@AuthenticationManager
			"../V1/V1Api": @V1Api
			"settings-sharelatex": @settings
			"logger-sharelatex": 
				log:->
				err:->
		@token = "12312321i"
		@user_id = "user_id_here"
		@user = 
			email : @email = "bob@bob.com"
		@password = "my great secret password"
		@callback = sinon.stub()


	describe "generateAndEmailResetToken", ->
		describe "when in ShareLaTeX", ->
			it "should check the user exists", (done)->
				@UserGetter.getUserByMainEmail.callsArgWith(1)
				@OneTimeTokenHandler.getNewToken.yields()
				@PasswordResetHandler.generateAndEmailResetToken @user.email, (err, exists)=>
					exists.should.equal false
					done()

			it "should send the email with the token", (done)->
				@UserGetter.getUserByMainEmail.callsArgWith(1, null, @user)
				@OneTimeTokenHandler.getNewToken.yields(null, @token)
				@EmailHandler.sendEmail.callsArgWith(2)
				@PasswordResetHandler.generateAndEmailResetToken @user.email, (err, exists)=>
					@EmailHandler.sendEmail.called.should.equal true
					exists.should.equal true
					args = @EmailHandler.sendEmail.args[0]
					args[0].should.equal "passwordResetRequested"
					args[1].setNewPasswordUrl.should.equal "#{@settings.siteUrl}/user/password/set?passwordResetToken=#{@token}&email=#{encodeURIComponent(@user.email)}"
					done()

			it "should return exists = false for a holdingAccount", (done) ->
				@user.holdingAccount = true
				@UserGetter.getUserByMainEmail.callsArgWith(1, null, @user)
				@OneTimeTokenHandler.getNewToken.yields()
				@PasswordResetHandler.generateAndEmailResetToken @user.email, (err, exists)=>
					exists.should.equal false
					done()

		describe "when in overleaf", ->
			beforeEach ->
				@settings.overleaf = true

			describe "when the email exists", ->
				beforeEach ->
					@V1Api.request.yields(null, {}, { user_id: 42 })
					@OneTimeTokenHandler.getNewToken.yields(null, @token)
					@EmailHandler.sendEmail.yields()
					@PasswordResetHandler.generateAndEmailResetToken @email, @callback

				it 'should call the v1 api for the user', ->
					@V1Api.request.calledWith({
						url: "/api/v1/sharelatex/user_emails"
						qs:
							email: @email
						expectedStatusCodes: [404]
					}).should.equal true

				it 'should set the password token data to the user id and email', ->
					@OneTimeTokenHandler.getNewToken
						.calledWith('password', {
							v1_user_id: 42,
							email: @email
						})
						.should.equal true

				it 'should send an email with the token', ->
					@EmailHandler.sendEmail.called.should.equal true
					args = @EmailHandler.sendEmail.args[0]
					args[0].should.equal "passwordResetRequested"
					args[1].setNewPasswordUrl.should.equal "#{@settings.siteUrl}/user/password/set?passwordResetToken=#{@token}&email=#{encodeURIComponent(@user.email)}"

				it 'should return exists == true', ->
					@callback.calledWith(null, true).should.equal true

			describe "when the email doesn't exist", ->
				beforeEach ->
					@V1Api.request = sinon.stub().yields(null, { statusCode: 404 }, {})
					@PasswordResetHandler.generateAndEmailResetToken @email, @callback

				it 'should not set the password token data', ->
					@OneTimeTokenHandler.getNewToken
						.called.should.equal false

				it 'should send an email with the token', ->
					@EmailHandler.sendEmail.called.should.equal false

				it 'should return exists == false', ->
					@callback.calledWith(null, false).should.equal true


	describe "setNewUserPassword", ->
		describe "when no data is found", ->
			beforeEach ->
				@OneTimeTokenHandler.getValueFromTokenAndExpire.yields(null, null)
				@PasswordResetHandler.setNewUserPassword @token, @password, @callback

			it 'should return exists == false', ->
				@callback.calledWith(null, false).should.equal true

		describe 'when the data is an old style user_id', ->
			beforeEach ->
				@AuthenticationManager.setUserPasswordInV2.yields(null, true, @user_id)
				@OneTimeTokenHandler.getValueFromTokenAndExpire.yields(null, @user_id)
				@PasswordResetHandler.setNewUserPassword @token, @password, @callback

			it 'should call setUserPasswordInV2', ->
				@AuthenticationManager.setUserPasswordInV2
					.calledWith(@user_id, @password)
					.should.equal true

			it 'should reset == true and the user_id', ->
				@callback.calledWith(null, true, @user_id).should.equal true

		describe 'when the data is a new style user_id', ->
			beforeEach ->
				@AuthenticationManager.setUserPasswordInV2.yields(null, true, @user_id)
				@OneTimeTokenHandler.getValueFromTokenAndExpire.yields(null, {@user_id})
				@PasswordResetHandler.setNewUserPassword @token, @password, @callback

			it 'should call setUserPasswordInV2', ->
				@AuthenticationManager.setUserPasswordInV2
					.calledWith(@user_id, @password)
					.should.equal true

			it 'should reset == true and the user_id', ->
				@callback.calledWith(null, true, @user_id).should.equal true

		describe 'when the data is v1 id', ->
			beforeEach ->
				@v1_user_id = 2345
				@AuthenticationManager.setUserPasswordInV1.yields(null, true)
				@UserGetter.getUser.withArgs({'overleaf.id': @v1_user_id}).yields(null, { _id: @user_id })
				@OneTimeTokenHandler.getValueFromTokenAndExpire.yields(null, {@v1_user_id, @email})
				@PasswordResetHandler.setNewUserPassword @token, @password, @callback

			it 'should call setUserPasswordInV1', ->
				@AuthenticationManager.setUserPasswordInV1
					.calledWith({
						email: @email,
						v1Id: @v1_user_id
						password: @password
					})
					.should.equal true

			it 'should look up the user by v1 id for the v2 user id', ->
				@UserGetter.getUser
					.calledWith({'overleaf.id': @v1_user_id})
					.should.equal true

			it 'should reset == true and the user_id', ->
				@callback.calledWith(null, true, @user_id).should.equal true
