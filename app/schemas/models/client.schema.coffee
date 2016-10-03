c = require './../schemas'

ClientSchema = {
  description: 'Third parties who can make API calls, usually on behalf of a user.'
  type: 'object'
  properties: {
    secret: {
      type: 'string'
      description: 'hashed version of a secret key that is required for API calls'
    }
  }
}

c.extendBasicProperties ClientSchema, 'Client'

module.exports = ClientSchema
