# API

* Routes
  * [POST /api/users](#post-apiusers)
  * [GET /api/users/:handle](#get-apiusershandle)
  * [POST /api/users/:handle/o-auth-identities](#post-apiusershandleo-auth-identities)
  * [GET /auth/login-o-auth](#get-authlogin-o-auth)
* Resources
  * [Users](#users)
  
## Basics
* Examples are in JavaScript on a Node/Express server with [request](https://github.com/request/request) installed.
* Request and responses are in JSON.
* API responses are the base resource being created/referenced. So, for example, all routes starting with `/api/users` return [User](#users) resources.

## Client Authentication

API routes must be called with Basic HTTP Authentication. Provide your username and password with each request.

```javascript
url = 'https://codecombat.com/api/users'
json = { name: 'A username' }
auth = { name: CLIENT_ID, pass: CLIENT_SECRET }
request.get({ url, json, auth }, (err, res) => console.log(res.statusCode, res.body))
```

## User Authentication

To authenticate a user on CodeCombat through your service, you will need to use OAuth 2. CodeCombat will act as the client, and your service will act as the provider. Your service will need to provide a trusted lookup URL where we can send the tokens given to us by users and receive user information. The process from user account creation to log in will look like this:

1. **Create the user**: Use `POST /api/users`.
1. **Link the CodeCombat user to an OAuth identity**: Use `POST /api/users/:handle/oauth-identities`, providing a token and your OAuth id which we will generate for you.
1. **Log the user in**: You redirect your user to `/auth/login-o-auth`, providing your OAuth id and token again.

# Routes

## POST /api/users
Creates a [user](#users).

#### Params
* `email`: String.
* `name`: String.

#### Example
```javascript
url = 'https://codecombat.com/api/users'
json = { email: 'an@email.com', name: 'Some Username' }
request.post({ url, json, auth })
```

## GET /api/users/:handle
Returns a [user](#users) with a given ID. `:handle` should be the user's `_id` or `slug` properties.

## POST /api/users/:handle/o-auth-identities
Adds an OAuth identity to the user, so that they can be logged in with that identity from then on. The token will be used to make a request to the provider's lookup URL, and use the provided `id`.

#### Params
* `provider`: String. Your OAuth Provider ID.
* `accessToken`: String. Will be passed through your lookup URL to get the user ID.

#### Example

In this example, your lookup URL is `https://oauth.provider/user?t=<%= accessToken %>'` and returns `{ id: 'abcd' }`

```javascript
url = `https://codecombat.com/api/users/${userID}/o-auth-identities`
OAUTH_PROVIDER_ID = 'xyz'
json = { provider: OAUTH_PROVIDER_ID, accessToken: '1234' }
request.post({ url, json, auth}, (err, res) => {
  console.log(res.body.oAuthIdentities) // [ { provider: 'xyx', id: 'abcd' } ]
})
```

## POST /api/users/:handle/prepaids
Grants a user premium access.

#### Params
* `endDate`: String. Must be ISO 8601 formatted UTC time, such as '2012-04-23T18:25:43.511Z'. JavaScript Date's `toISOString` returns this format.

#### Example

```javascript
url = `https://codecombat.com/api/users/${userID}/prepaids`
json = { json: new Date('2017-01-01').toISOString() }
request.post({ url, json, auth }, (err, res) => {
  console.log(res.body.subscription) // { ends: '2017-01-01T00:00:00.000Z', active: true }
})
```

## GET /auth/login-o-auth
Logs a user in given the token.

#### Params
* `provider`: String. Your OAuth Provider ID.
* `accessToken`: String. Will be passed through your lookup URL to get the user ID.

#### Returns
A redirect to the home page and cookie-setting headers.

#### Example

In this example, your lookup URL is `https://oauth.provider/user?t=<%= accessToken %>'` and returns `{ id: 'abcd' }`

```javascript
url = `https://codecombat.com/auth/login-o-auth?provider=${OAUTH_PROVIDER_ID}&accessToken=1234`
res.redirect(url)
// User is sent to CodeCombat and assuming everything checks out, 
// is logged in and redirected to the home page.
```

# Resources

## Users

#### Properties
This is a subset of all the User properties.

* `_id`: String.
* `email`: String.
* `name`: String.
* `slug`: String. Kebab-cased version of `name`. This property is kept unique among CodeCombat users.
* `stats`: Object.
  * `gamesCompleted`: Number.
  * `concepts`: Object. Values are numbers. Keys are concepts as listed in [schemas.coffee](https://github.com/codecombat/codecombat/blob/master/app/schemas/schemas.coffee).
* `oAuthIdentities`: Array of Objects.
  * `provider`: String.
  * `id`: String.
