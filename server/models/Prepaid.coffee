Promise = require 'bluebird'
mongoose = require 'mongoose'
config = require '../../server_config'
PrepaidSchema = new mongoose.Schema {
  creator: mongoose.Schema.Types.ObjectId
}, {strict: false, minimize: false,read:config.mongo.readpref}
co = require 'co'
jsonSchema = require '../../app/schemas/models/prepaid.schema'
errors = require '../commons/errors'
{ findStripeSubscriptionAsync } = require '../lib/utils'
{ cancelSubscriptionImmediatelyAsync } = require '../lib/stripe_utils'

PrepaidSchema.index({code: 1}, { unique: true })
PrepaidSchema.index({'redeemers.userID': 1})
PrepaidSchema.index({owner: 1, endDate: 1}, { sparse: true })

PrepaidSchema.statics.DEFAULT_START_DATE = new Date(2016,4,15).toISOString()
PrepaidSchema.statics.DEFAULT_END_DATE = new Date(2017,5,1).toISOString()

PrepaidSchema.statics.generateNewCode = (done) ->
  # Deprecated for not following Node callback convention. TODO: Remove
  tryCode = ->
    code = _.sample("abcdefghijklmnopqrstuvwxyz0123456789", 8).join('')
    Prepaid.findOne code: code, (err, prepaid) ->
      return done() if err
      return done(code) unless prepaid
      tryCode()
  tryCode()
  
PrepaidSchema.statics.generateNewCodeAsync = co.wrap (done) ->
  code = null
  while true
    code = _.sample("abcdefghijklmnopqrstuvwxyz0123456789", 8).join('')
    prepaid = yield Prepaid.findOne({code: code})
    break if not prepaid
  return code

PrepaidSchema.pre('save', (next) ->
  @set('exhausted', @get('maxRedeemers') <= _.size(@get('redeemers')))
  if not @get('code')
    Prepaid.generateNewCode (code) =>
      @set('code', code)
      next()
  else
    next()
)

PrepaidSchema.post 'init', (doc) ->
  doc.set('maxRedeemers', parseInt(doc.get('maxRedeemers') ? 0))
  if @get('type') is 'course'
    if not @get('startDate')
      @set('startDate', Prepaid.DEFAULT_START_DATE)
    if not @get('endDate')
      @set('endDate', Prepaid.DEFAULT_END_DATE)
      
PrepaidSchema.methods.redeem = co.wrap (user) ->
  oldRedeemers = @get('redeemers') ? []
  if oldRedeemers.length >= @get('maxRedeemers')
    throw new errors.Forbidden('Too many redeemers')
    
  months = parseInt(@get('properties')?.months)
  if isNaN(months) or months < 1
    throw new errors.UnprocessableEntity('Bad months') 
  
  for redeemer in oldRedeemers
    if redeemer.userID.equals(user._id)
      throw new errors.Forbidden('User already redeemed')

  newRedeemerPush = { $push: { redeemers : { date: new Date(), userID: user._id } }}
  try
    result = yield Prepaid.update(
      { 
        _id: @_id,
        'redeemers.userID': { $ne: user._id },
        '$where': 'this.redeemers.length < this.maxRedeemers'
      }, newRedeemerPush)
  catch e
    # TODO: Replace special subscription error handling
    msg = "Subscribe with Prepaid Code update: #{JSON.stringify(e)}"
    log.warn "Subscription Error: #{user.get('slug')} (#{user.id}): '#{msg}'"
    throw e
  
  if result.nModified isnt 1
    throw new errors.Forbidden('Can\'t add user to prepaid redeemers')
    
  { customerID, subscriptionID } = user.get('stripe') ? {}
  subscription = yield findStripeSubscriptionAsync(customerID, {subscriptionID})

  if subscription
    try
      stripeSubscriptionPeriodEndDate = new Date(subscription.current_period_end * 1000)
      yield cancelSubscriptionImmediatelyAsync(user, subscription)
    catch e
      msg = "Redeem Prepaid Code Stripe cancel subscription error: #{JSON.stringify(e)}"
      log.warn "Subscription Error: #{user.get('slug')} (#{user.id}): '#{msg}'"
      throw e

  Product = require './Product'
  product = yield Product.findOne({name: 'basic_subscription'})
  if not product
    throw new errors.NotFound('basic_subscription product not found') 

  # Add terminal subscription to User, extending existing subscriptions
  # TODO: refactor this into some form useable by both this and purchaseYearSale
  stripeInfo = _.cloneDeep(user.get('stripe') ? {})
  moment = require 'moment'
  endDate = new moment()
  if stripeSubscriptionPeriodEndDate
    endDate = new moment(stripeSubscriptionPeriodEndDate)
  else if _.isString(stripeInfo.free) and new moment().isBefore(new moment(stripeInfo.free))
    endDate = new moment(stripeInfo.free)
  endDate = endDate.add(months, 'months')
  stripeInfo.free = endDate.toISOString().substring(0, 10)
  user.set('stripe', stripeInfo)

  # Add gems to User
  purchased = _.clone(user.get('purchased'))
  purchased ?= {}
  purchased.gems ?= 0
  purchased.gems += product.get('gems') * months if product.get('gems')
  user.set('purchased', purchased)

  try
    yield user.save()
  catch e
    msg = "User save error: #{JSON.stringify(e)}"
    log.warn "Subscription Error: #{user.get('slug')} (#{user.id}): '#{msg}'"
    throw e


PrepaidSchema.statics.postEditableProperties = [
  'creator', 'maxRedeemers', 'properties', 'type', 'startDate', 'endDate'
]
PrepaidSchema.statics.editableProperties = []
PrepaidSchema.statics.jsonSchema = jsonSchema

module.exports = Prepaid = mongoose.model('prepaid', PrepaidSchema)
