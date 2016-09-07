sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../app/js/PublicRegistrationController.js"
SandboxedModule = require('sandboxed-module')
events = require "events"
ObjectId = require("mongojs").ObjectId
assert = require("assert")

describe "PublicRegistrationController", ->
	beforeEach ->
		@user_id = "323123"

		@user =
			_id:@user_id
			save:sinon.stub().callsArgWith(0)
			ace:{}

		@UserRegistrationHandler =
			registerNewUser: sinon.stub()
		@ReferalAllocator =
			allocate:sinon.stub()
		@SubscriptionDomainHandler =
			getDomainLicencePage:sinon.stub()
		@UserUpdater =
			changeEmailAddress:sinon.stub()
		@EmailHandler =
			sendEmail:sinon.stub().callsArgWith(2)
		@UserHandler =
			populateGroupLicenceInvite: sinon.stub().callsArgWith(1)
		@PublicRegistrationController = SandboxedModule.require modulePath, requires:
			"../../../../app/js/Features/User/UserRegistrationHandler":@UserRegistrationHandler
			"../../../../app/js/Features/Referal/ReferalAllocator":@ReferalAllocator
			"../../../../app/js/Features/Subscription/SubscriptionDomainHandler":@SubscriptionDomainHandler
			"../../../../app/js/Features/Email/EmailHandler": @EmailHandler
			"../../../../app/js/Features/Email/Layouts/PersonalEmailLayout":{}
			"../../../../app/js/Features/Email/EmailBuilder": templates:{welcome:{}}
			"../../../../app/js/Features/User/UserHandler": @UserHandler
			"logger-sharelatex": {log:->}
			"metrics-sharelatex": { inc: () ->}


		@req =
			session:
				destroy:->
				user :
					_id : @user_id
			body:{}
			login: sinon.stub().callsArgWith(1, null)  # passport
		@res = {json: sinon.stub()}
		@next = sinon.stub()

	describe "register", ->
		it "should ask the UserRegistrationHandler to register user", (done)->
			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			@res.json = =>
				@UserRegistrationHandler.registerNewUser.calledWith(@req.body).should.equal true
				done()
			@PublicRegistrationController.register @req, @res

		it "should try and log the user in if there is an EmailAlreadyRegistered error", (done)->

			@UserRegistrationHandler.registerNewUser.callsArgWith(1, new Error("EmailAlreadyRegistered"))
			# @AuthenticationController.login = (req, res)=>
			# 	assert.deepEqual req, @req
			# 	assert.deepEqual res, @res
			# 	done()
			@PublicRegistrationController.register @req, @res
			@req.login.callCount.should.equal 1
			done()

		it "should put the user on the session and mark them as justRegistered", (done)->
			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			@res.json = =>
				@req.login
					.calledWith(@user)
					.should.equal true
				assert.equal @req.session.justRegistered, true
				done()
			@PublicRegistrationController.register @req, @res

		it "should redirect to project page", (done)->
			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			@res.json = (opts)=>
				opts.redir.should.equal "/project"
				done()
			@PublicRegistrationController.register @req, @res


		it "should redirect passed redir if it exists", (done)->
			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			@req.body.redir = "/somewhere"
			@res.json = (opts)=>
				opts.redir.should.equal "/somewhere"
				done()
			@PublicRegistrationController.register @req, @res

		it "should allocate the referals", (done)->
			@req.session =
				referal_id : "23123"
				referal_source : "email"
				referal_medium : "bob"

			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			@req.body.redir = "/somewhere"
			@res.json = (opts)=>
				@ReferalAllocator.allocate.calledWith(@req.session.referal_id, @user._id, @req.session.referal_source, @req.session.referal_medium).should.equal true
				done()
			@PublicRegistrationController.register @req, @res

		it "should call populateGroupLicenceInvite", (done)->
			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			@res.json = (opts)=>
				@UserHandler.populateGroupLicenceInvite.calledWith(@user).should.equal true
				done()
			@PublicRegistrationController.register @req, @res


		it "should send user to verifiy link if they are part of domain licnece", (done)->
			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			stubbedVerifiyLink = "/go/here/domain/person"
			@SubscriptionDomainHandler.getDomainLicencePage.returns(stubbedVerifiyLink)
			@res.json = (opts)=>
				@SubscriptionDomainHandler.getDomainLicencePage.calledWith(@user).should.equal true
				opts.redir.should.equal stubbedVerifiyLink
				done()
			@PublicRegistrationController.register @req, @res

		it "should send a welcome email", (done)->
			@UserRegistrationHandler.registerNewUser.callsArgWith(1, null, @user)
			@res.json = (opts)=>
				@EmailHandler.sendEmail.calledWith("welcome").should.equal true
				done()
			@PublicRegistrationController.register @req, @res
