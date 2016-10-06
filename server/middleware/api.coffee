basicAuth = require('basic-auth')
Client = require '../models/Client'
User = require '../models/User'
wrap = require 'co-express'
errors = require '../commons/errors'
database = require '../commons/database'
config = require '../../server_config'
OAuthProvider = require '../models/OAuthProvider'
Prepaid = require '../models/Prepaid'
moment = require 'moment'

INCLUDED_PRIVATES = ['email', 'oAuthIdentities']
DATETIME_REGEX = /^\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}\.\d{3}Z$/ # JavaScript Date's toISOString() output

clientAuth = wrap (req, res, next) ->
  if config.isProduction and not req.secure  
    throw new errors.Unauthorized('API calls must be over HTTPS.')

  creds = basicAuth(req)

  unless creds and creds.name and creds.pass
    throw new errors.Unauthorized('Basic auth credentials not provided.')
    
  client = yield Client.findById(creds.name)
  if not client
    throw new errors.Unauthorized('Credentials incorrect.')
    
  hashed = Client.hash(creds.pass)
  if client.get('secret') isnt hashed
    throw new errors.Unauthorized('Credentials incorrect.')

  req.client = client
  next()

  
postUser = wrap (req, res) ->
  user = new User({anonymous: false})
  user.set(_.pick(req.body, 'name', 'email'))
  user.set('clientCreator', req.client._id)
  database.validateDoc(user)
  user = yield user.save()
  res.status(201).send(user.toObject({req, includedPrivates: INCLUDED_PRIVATES, virtuals: true}))
  
  
getUser = wrap (req, res) ->
  user = yield database.getDocFromHandle(req, User)
  if not user
    throw new errors.NotFound('User not found.')

  unless req.client._id.equals(user.get('clientCreator'))
    throw new errors.Forbidden('Must have created the user.')

  res.send(user.toObject({req, includedPrivates: INCLUDED_PRIVATES, virtuals: true}))
  
  
postUserOAuthIdentity = wrap (req, res) ->
  user = yield database.getDocFromHandle(req, User)
  if not user
    throw new errors.NotFound('User not found.')
    
  unless req.client._id.equals(user.get('clientCreator'))
    throw new errors.Forbidden('Must have created the user to perform this action.')
    
  { provider: providerID, accessToken, code } = req.body or {}
  unless providerID and (accessToken or code)
    throw new errors.UnprocessableEntity('Properties "provider" and "accessToken" or "code" required.')
    
  if not database.isID(providerID)
    throw new errors.UnprocessableEntity('"provider" is not a valid id')
    
  provider = yield OAuthProvider.findById(providerID)
  if not provider
    throw new errors.NotFound('Provider not found.')
    
  if code and not accessToken
    { access_token: accessToken } = yield provider.getTokenWithCode(code)
    if not accessToken
      throw new errors.UnprocessableEntity('Code lookup failed')

  userData = yield provider.lookupAccessToken(accessToken)
  if not userData
    throw new errors.UnprocessableEntity('User lookup failed')
    
  identity = {
    provider: provider._id
    id: userData.id
  }

  otherUser = yield User.findOne({oAuthIdentities: { $elemMatch: identity }})
  if otherUser
    throw new errors.Conflict('User already exists with this identity')

  yield user.update({$push: {oAuthIdentities: identity}})
  oAuthIdentities = user.get('oAuthIdentities') or []
  oAuthIdentities.push(identity)
  user.set({oAuthIdentities})
  res.send(user.toObject({req, includedPrivates: INCLUDED_PRIVATES, virtuals: true}))
  
  
postUserPrepaid = wrap (req, res) ->
  user = yield database.getDocFromHandle(req, User)
  if not user
    throw new errors.NotFound('User not found.')

  unless req.client._id.equals(user.get('clientCreator'))
    throw new errors.Forbidden('Must have created the user to perform this action.')
    
  { endDate } = req.body
  unless endDate and DATETIME_REGEX.test(endDate)
    throw new errors.UnprocessableEntity('endDate is not a properly formatted.')
    
  # this prepaid goes from when the user 
  { free } = user.get('stripe') ? {}
  if free is true
    throw new errors.UnprocessableEntity('This user already has free premium access')
    
  startDate = if _.isString(free) then moment(free).toISOString() else new Date().toISOString()
  if startDate >= endDate
    throw new errors.UnprocessableEntity("endDate is before when the subscription would start: #{startDate}")
    
  prepaid = new Prepaid({
    clientCreator: req.client._id
    redeemers: []
    maxRedeemers: 1
    type: 'terminal_subscription'
    startDate
    endDate
  })
  yield prepaid.save()
  yield prepaid.redeem(user)
  res.send(user.toObject({req, includedPrivates: INCLUDED_PRIVATES, virtuals: true}))


module.exports = {
  clientAuth
  getUser
  postUser
  postUserOAuthIdentity
  postUserPrepaid
}
