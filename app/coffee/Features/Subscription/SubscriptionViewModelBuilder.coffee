Settings = require('settings-sharelatex')
RecurlyWrapper = require("./RecurlyWrapper")
PlansLocator = require("./PlansLocator")
SubscriptionFormatters = require("./SubscriptionFormatters")
LimitationsManager = require("./LimitationsManager")
SubscriptionLocator = require("./SubscriptionLocator")
V1SubscriptionManager = require("./V1SubscriptionManager")
logger = require('logger-sharelatex')
_ = require("underscore")
async = require('async')


buildBillingDetails = (recurlySubscription) ->
	hostedLoginToken = recurlySubscription?.account?.hosted_login_token
	recurlySubdomain = Settings?.apis?.recurly?.subdomain
	if hostedLoginToken? && recurlySubdomain?
		return [
			"https://",
			recurlySubdomain,
			".recurly.com/account/billing_info/edit?ht=",
			hostedLoginToken
		].join("")

module.exports =
	buildUsersSubscriptionViewModel: (user, callback = (error, subscription, memberSubscriptions, billingDetailsLink) ->) ->
		async.auto {
			personalSubscription: (cb) ->
				SubscriptionLocator.getUsersSubscription user, cb
			recurlySubscription: ['personalSubscription', (cb, {personalSubscription}) ->
				if !personalSubscription?.recurlySubscription_id? or personalSubscription?.recurlySubscription_id == ''
					return cb(null, null) 
				RecurlyWrapper.getSubscription personalSubscription.recurlySubscription_id, includeAccount: true, cb
			]
			plan: ['personalSubscription', (cb, {personalSubscription}) ->
				return cb() if !personalSubscription?
				plan = PlansLocator.findLocalPlanInSettings(personalSubscription.planCode)
				return cb(new Error("No plan found for planCode '#{personalSubscription.planCode}'")) if !plan?
				personalSubscription.plan = plan
				cb()
			]
			groupSubscriptions: (cb) ->
				SubscriptionLocator.getMemberSubscriptions user, cb
			v1Subscriptions: (cb) ->
				V1SubscriptionManager.getSubscriptionsFromV1 user._id, (error, subscriptions) ->
					return cb(error) if error?
					cb(null, subscriptions)
		}, (err, results) ->
			return callback(err) if err?
			{personalSubscription, groupSubscriptions, v1Subscriptions, recurlySubscription} = results
			groupSubscriptions ?= []
			v1Subscriptions ?= []

			if personalSubscription?.toObject?
				# Downgrade from Mongoose object, so we can add a recurly attribute
				personalSubscription = personalSubscription.toObject()

			console.log 'recurlySubscription', recurlySubscription

			if personalSubscription? and recurlySubscription?
				tax = recurlySubscription?.tax_in_cents || 0
				personalSubscription.recurly = {
					tax: tax
					taxRate: taxRate:parseFloat(recurlySubscription?.tax_rate?._)
					billingDetailsLink: buildBillingDetails(recurlySubscription)
					price: SubscriptionFormatters.formatPrice (recurlySubscription?.unit_amount_in_cents + tax), recurlySubscription?.currency
					nextPaymentDueAt: SubscriptionFormatters.formatDate(recurlySubscription?.current_period_ends_at)
					currency: recurlySubscription.currency
					state: recurlySubscription.state
				}

			callback null, {
				personalSubscription, groupSubscriptions, v1Subscriptions
			}

	buildViewModel : ->
		plans = Settings.plans

		allPlans = {}
		plans.forEach (plan)->
			allPlans[plan.planCode] = plan

		result =
			allPlans: allPlans


		result.personalAccount = _.find plans, (plan)->
			plan.planCode == "personal"

		result.studentAccounts = _.filter plans, (plan)->
			plan.planCode.indexOf("student") != -1

		result.groupMonthlyPlans = _.filter plans, (plan)->
			plan.groupPlan and !plan.annual

		result.groupAnnualPlans = _.filter plans, (plan)->
			plan.groupPlan and plan.annual

		result.individualMonthlyPlans = _.filter plans, (plan)->
			!plan.groupPlan and !plan.annual and plan.planCode != "personal" and plan.planCode.indexOf("student") == -1

		result.individualAnnualPlans = _.filter plans, (plan)->
			!plan.groupPlan and plan.annual and plan.planCode.indexOf("student") == -1

		return result
