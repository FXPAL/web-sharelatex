should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
Path = require('path')
modulePath = Path.join __dirname, '../../../../app/js/Authentication/OverleafAuthenticationController'
sinon = require("sinon")
expect = require("chai").expect

describe "OverleafAuthenticationController", ->
	beforeEach ->
		@OverleafAuthenticationController = SandboxedModule.require modulePath, requires:
			"../../../../../app/js/Features/Authentication/AuthenticationController": @AuthenticationController = {}
			"logger-sharelatex": { log: sinon.stub(), err: sinon.stub() }
			"passport": @passport = {}
			"settings-sharelatex": @settings =
				accountMerge:
					sharelatexHost: "http://sl.example.com"
					secret: "banana"
			"jsonwebtoken": @jwt = {}
			"../OverleafUsers/UserMapper": @UserMapper = {}
			"../../../../../app/js/Features/Subscription/FeaturesUpdater":
				@FeaturesUpdater = {refreshFeatures: sinon.stub()}
		@req =
			logIn: sinon.stub()
			session: {}
		@res =
			redirect: sinon.stub()
			status: sinon.stub()
			send: sinon.stub()
			render: sinon.stub()
		@res.status.returns(@res)

	describe "setupUser", ->
		describe "with a conflicting email", ->
			beforeEach ->
				# Our code is wrapped in passport:
				# (req, res, next) ->
				# 	passport.authenticate("oauth2", (err, user, info) ->
				# 		method we want to test...
				# 	)(req, res, next)
				@AuthenticationController.finishLogin = sinon.stub()
				@passport.authenticate = (provider, method) =>
					return (req, res, next) =>
						method(null, null, {
							email_exists_in_sl: true
							profile: @profile = {
								email: "test@example.com"
							}
							accessToken: @accessToken = "access-token"
							refreshToken: @refreshToken = "refresh-token"
							user_id: @user_id = "mock-sl-user-id"
						})
				@jwt.sign = sinon.stub().returns @token = "mock-token"
				@OverleafAuthenticationController.setupUser @req, @res, @next

			it 'should sign the redirect data in a JWT', ->
				@jwt.sign
					.calledWith(
						{ @user_id, overleaf_email: @profile.email, confirm_merge: true },
						@settings.accountMerge.secret,
						{ expiresIn: '1h' }
					)
					.should.equal true

			it 'should save the OAuth and user data in the session', ->
				expect(@req.session.accountMerge).to.deep.equal {
					@profile, @user_id, @accessToken, @refreshToken
				}

			it "should render the confirmation page", ->
				@res.render
					.calledWith(
						Path.resolve(__dirname, "../../../../app/views/confirm_merge"),
						{
							redirect_url: "#{@settings.accountMerge.sharelatexHost}/user/confirm_account_merge?token=#{@token}"
							email: @profile.email
							suppressNavbar: true
						}
					)
					.should.equal true

		describe "with a successful user set up", ->
			beforeEach ->
				@AuthenticationController.finishLogin = sinon.stub()
				@passport.authenticate = (provider, method) =>
					return (req, res, next) =>
						method(null, @user = {"mock": "user"}, null)
				@OverleafAuthenticationController.setupUser @req, @res, @next

			it "should log the user in", ->
				@AuthenticationController.finishLogin
					.calledWith(@user, @req, @res, @next)
					.should.equal true

	# describe "doLogin", ->
	# 	beforeEach ->
	# 		@user = {"mock": "user"}
	# 		@req.user = @user
	# 		@AuthenticationController.afterLoginSessionSetup = sinon.stub().yields()
	# 		@AuthenticationController._getRedirectFromSession = sinon.stub()
	# 		@AuthenticationController._getRedirectFromSession.withArgs(@req).returns @redir = "/redir/path"
	# 		@OverleafAuthenticationController.doLogin @req, @res, @next

	# 	it "should call AuthenticationController.afterLoginSessionSetup", ->
	# 		@AuthenticationController.afterLoginSessionSetup
	# 			.calledWith(@req, @user)
	# 			.should.equal true

	# 	it "should redirect to the stored rediret", ->
	# 		@res.redirect
	# 			.calledWith(@redir)
	# 			.should.equal true

	describe "confirmedAccountMerge", ->
		beforeEach ->
			@token = "mock-token"
			@user_id = "mock-user-id"
			@data = {
				merge_confirmed: true
				user_id: @user_id
			}
			@AuthenticationController.finishLogin = sinon.stub()
			@UserMapper.mergeWithSlUser = sinon.stub().yields(null, @user = {"mock": "user"})
			@jwt.verify = sinon.stub()
			@jwt.verify.withArgs(@token, @settings.accountMerge.secret).yields(null, @data)
			@req.session.accountMerge = {
				accessToken: 'mock-access-token'
				refreshToken: 'mock-refresh-token'
				user_id: @user_id
				profile: {
					email: "jim@example.com"
				}
			}
			@req.query = token: @token

		describe "successfully", ->
			beforeEach ->
				@OverleafAuthenticationController.confirmedAccountMerge(@req, @res, @next)

			it "should verify the token", ->
				@jwt.verify
					.calledWith(@token, @settings.accountMerge.secret)
					.should.equal true

			it "should merge with the SL user based on session data", ->
				@UserMapper.mergeWithSlUser
					.calledWith(
						@user_id,
						@req.session.accountMerge.profile,
						@req.session.accountMerge.accessToken,
						@req.session.accountMerge.refreshToken
					)
					.should.equal true

			it "should log the user in", ->
				@AuthenticationController.finishLogin
					.calledWith(@user, @req, @res, @next)
					.should.equal true

		describe "with no token", ->
			beforeEach ->
				@req.query = {}
				@OverleafAuthenticationController.confirmedAccountMerge(@req, @res, @next)

			it "should return a 400 invalid token error", ->
				@res.status.calledWith(400).should.equal true

			it "should not try to verify the token", ->
				@jwt.verify.called.should.equal false

		describe "with invalid token (no merge_confirmed parameter)", ->
			beforeEach ->
				delete @data.merge_confirmed
				@OverleafAuthenticationController.confirmedAccountMerge(@req, @res, @next)

			it "should return a 400 invalid token error", ->
				@res.status.calledWith(400).should.equal true

		describe "when user_id in token doesn't match saved user_id", ->
			beforeEach ->
				@data.user_id = "not-the-saved-user-id"
				@OverleafAuthenticationController.confirmedAccountMerge(@req, @res, @next)

			it "should return a 400 invalid token error", ->
				@res.status.calledWith(400).should.equal true


