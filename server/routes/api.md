# API Routes

Examples are in JavaScript using the [request package](https://github.com/request/request). Requests use JSON.

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
1. **Link the CodeCombat user to an OAuth identity**: Use `POST /api/users/:handle/oauth-identities`, providing a token and your OAuth id.
1. **Log the user in**: In progress, but essentially you will redirect the user to a url which includes the same sort of token. We'll lookup the token and which user has that identity, and log the user in accordingly.

## Routes

### POST /api/users
Creates a user.

#### Params
* `email`
* `name`

#### Returns
A user object, including properties:
* `_id`
* `email`
* `name`

#### Example
```javascript
url = 'https://codecombat.com/api/users'
json = { email: 'an@email.com', name: 'Some Username' }
request.post({ url, json, auth })
```

### POST /api/users/:handle/o-auth-identities
Adds an OAuth identity to the user, so that they can be logged in with that identity from then on. The token will be used to make a request to the provider's lookup URL, and use the provided `id`.

#### Params
* `provider`
* `accessToken`

#### Returns
A user object, including the property `oAuthIdentities`.

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
