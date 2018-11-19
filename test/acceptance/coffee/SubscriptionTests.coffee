expect = require('chai').expect
async = require("async")
User = require "./helpers/User"
{Subscription} = require "../../../app/js/models/Subscription"

MockRecurlyApi = require "./helpers/MockRecurlyApi"

describe 'Subscriptions', ->
	describe 'dashboard', ->
		before (done) ->
			@user = new User()
			@user.login done

		describe 'when the user has no subscription', ->
			before (done) ->
				@user.request {
					url: '/user/subscription'
					json: true
				}, (error, response, @data) =>
					return done(error) if error?
					expect(response.statusCode).to.equal 200
					done()

			it 'should return no personalSubscription', ->
				expect(@data.personalSubscription).to.equal null

			it 'should return no groupSubscriptions', ->
				expect(@data.groupSubscriptions).to.deep.equal []

			it 'should return no v1Subscriptions', ->
				expect(@data.v1Subscriptions).to.deep.equal []

		describe 'when the user has a subscription with recurly', ->
			before (done) ->
				MockRecurlyApi.accounts['mock-account-id'] = @accounts = {
					hosted_login_token: 'mock-login-token'
				}
				MockRecurlyApi.subscriptions['mock-subscription-id'] = @subscription = {
					plan_code: 'collaborator',
					tax_in_cents: 100,
					tax_rate: 0.2,
					unit_amount_in_cents: 500,
					currency: 'GBP',
					current_period_ends_at: new Date(2018,4,5),
					state: 'active',
					account_id: 'mock-account-id'
				}
				Subscription.create {
					admin_id: @user._id,
					manager_ids: [@user._id],
					recurlySubscription_id: 'mock-subscription-id',
					planCode: 'collaborator'
				}, (error) =>
					return done(error) if error?
					@user.request {
						url: '/user/subscription'
						json: true
					}, (error, response, @data) =>
						return done(error) if error?
						expect(response.statusCode).to.equal 200
						done()
				return

			after (done) ->
				MockRecurlyApi.accounts = {}
				MockRecurlyApi.subscriptions = {}
				Subscription.remove {
					admin_id: @user._id
				}, done
				return

			it 'should return a personalSubscription with populated recurly data', ->
				subscription = @data.personalSubscription
				expect(subscription).to.exist
				expect(subscription.planCode).to.equal 'collaborator'
				expect(subscription.recurly).to.exist
				expect(subscription.recurly).to.deep.equal {
					"billingDetailsLink": "https://test.recurly.com/account/billing_info/edit?ht=mock-login-token"
					"currency": "GBP"
					"nextPaymentDueAt": "5th May 2018"
					"price": "£6.00"
					"state": "active"
					"tax": 100
					"taxRate": {
						"taxRate": 0.2
					}
				}

			it 'should return no groupSubscriptions', ->
				expect(@data.groupSubscriptions).to.deep.equal []

		describe 'when the user has a subscription without recurly', ->
			before (done) ->
				Subscription.create {
					admin_id: @user._id,
					manager_ids: [@user._id],
					planCode: 'collaborator'
				}, (error) =>
					return done(error) if error?
					@user.request {
						url: '/user/subscription'
						json: true
					}, (error, response, @data) =>
						return done(error) if error?
						expect(response.statusCode).to.equal 200
						done()
				return

			it 'should return a personalSubscription with no recurly data', ->
				subscription = @data.personalSubscription
				expect(subscription).to.exist
				expect(subscription.planCode).to.equal 'collaborator'
				expect(subscription.recurly).to.not.exist

			it 'should return no groupSubscriptions', ->
				expect(@data.groupSubscriptions).to.deep.equal []

		describe.only 'when the user is a member of a group subscription', ->
			before (done) ->
				@owner1 = new User()
				@owner2 = new User()
				async.series [
					(cb) => @owner1.ensureUserExists cb
					(cb) => @owner2.ensureUserExists cb
					(cb) => Subscription.create {
							admin_id: @owner1._id,
							manager_ids: [@owner1._id],
							planCode: 'collaborator',
							groupPlan: true,
							member_ids: [@user._id]
						}, cb
					(cb) => Subscription.create {
							admin_id: @owner2._id,
							manager_ids: [@owner2._id],
							planCode: 'collaborator',
							groupPlan: true,
							member_ids: [@user._id]
						}, cb
				], (error) =>				
					return done(error) if error?
					@user.request {
						url: '/user/subscription'
						json: true
					}, (error, response, @data) =>
						return done(error) if error?
						expect(response.statusCode).to.equal 200
						done()
				return

			it 'should return no personalSubscription', ->
				expect(@data.personalSubscription).to.equal null

			it 'should return the two groupSubscriptions', ->
				expect(@data.groupSubscriptions.length).to.equal 2
				expect(
					# Mongoose populates the admin_id with the user
					@data.groupSubscriptions[0].admin_id._id
				).to.equal @owner1._id
				expect(
					@data.groupSubscriptions[1].admin_id._id
				).to.equal @owner2._id