config = require '../../config'
utils = require './utils'
{renderAccount, errorHandling, requestAuthenticate} = require './middleware'

mAccount = require '../model/account'

module.exports = exports = express.Router()

exports.get '/signup', renderAccount, (req, res) ->
  res.render 'account/signup'

exports.get '/login', renderAccount, (req, res) ->
  res.render 'account/login'

exports.post '/signup', errorHandling, (req, res) ->
  unless utils.rx.username.test req.body.username
    return res.error 'invalid_username'

  unless utils.rx.email.test req.body.email
    return res.error 'invalid_email'

  unless utils.rx.password.test req.body.password
    return res.error 'invalid_password'

  if req.body.username in config.account.invalid_username
    return res.error 'username_exist'

  mAccount.byUsername req.body.username, (err, account) ->
    if account
      return res.error 'username_exist'

    mAccount.byEmail req.body.email, (err, account) ->
      if account
        return res.error 'email_exist'

      mAccount.register req.body.username, req.body.email, req.body.password, (err, account) ->
        mAccount.createToken account, {}, (err, token)->
          res.cookie 'token', token,
            expires: new Date(Date.now() + config.account.cookie_time)

          res.json
            id: account._id

exports.post '/login', errorHandling, (req, res) ->
  mAccount.byUsernameOrEmailOrId req.body.username, (err, account) ->
    unless account
      return res.error 'auth_failed'

    unless mAccount.matchPassword account, req.body.password
      return res.error 'auth_failed'

    mAccount.createToken account, {}, (err, token) ->
      res.cookie 'token', token,
        expires: new Date(Date.now() + config.account.cookie_time)

      res.json
        id: account._id
        token: token

exports.post '/logout', requestAuthenticate, (req, res) ->
  mAccount.removeToken req.token, ->
    res.clearCookie 'token'
    res.json {}

exports.post '/update_password', requestAuthenticate, (req, res) ->
  unless mAccount.matchPassword account, req.body.old_password
    return res.error 'auth_failed'

  unless utils.rx.password.test req.body.password
    return res.error 'invalid_password'

  mAccount.updatePassword account, req.body.new_password, ->
    res.json {}
