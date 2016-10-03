mongoose = require 'mongoose'
plugins = require '../plugins/plugins'
log = require 'winston'
config = require '../../server_config'
jsonSchema = require '../../app/schemas/models/client.schema.coffee'
crypto = require 'crypto'

ClientSchema = new mongoose.Schema(body: String, {strict: false,read:config.mongo.readpref})

ClientSchema.statics.jsonSchema = jsonSchema
ClientSchema.statics.editableProperties = [
  'name'
]

ClientSchema.methods.generateNewSecret = ->
  secret = _.times(40, -> (_.random(0,Math.pow(2,4)-1)).toString(16)).join('') # 40 hex character string
  shasum = crypto.createHash('sha512').update(config.salt + secret)
  hashed = shasum.digest('hex')
  @set('secret', hashed)
  return secret

ClientSchema.statics.postEditableProperties = []

ClientSchema.set('toObject', {
  transform: (doc, ret, options) ->
    req = options.req
    if not req?
      throw new Error('toObject not given request object')
    delete ret.secret
    return ret
})

module.exports = mongoose.model('client', ClientSchema)
