crypto = require 'crypto'

config = require '../../config'
bitcoin = require '../bitcoin'

mBalance = require './balance'

module.exports = exports = app.db.buildModel 'accounts'

exports.byUsername = exports.buildByXXOO 'username', exports
exports.byEmail = exports.buildByXXOO 'email', exports
exports.byDepositAddress = exports.buildByXXOO 'bitcoin_deposit_address', exports

sample =
  username: 'jysperm'
  password: '53673f434686ce045477f066f30eded55a9bb535a6cec7b73a60972ccafddb2a'
  password_salt: '53673f434686b535a6cec7b73a60ce045477f066f30eded55a9b972ccafddb2a'
  email: 'jysperm@gmail.com'
  signup_at: Date()

  group: ['root']

  setting:
    avatar_url: 'http://ruby-china.org/avatar/efcc15b92617a95a09f514a9bff9e6c3?s=58'
    language: 'zh_CN'
    QQ: '184300584'

  attribute:
    bitcoin_deposit_address: '13v2BTCMZMHg5v87susgg86HFZqXERuwUd'
    blockchain_secret: '53673f434686b535a6cec7b73a60ce045477f066f30eded55a9b972ccafddb2a'

    services: ['shadowsocks']
    plans: ['all']

    balance: 100
    last_billing_at: Date()
    arrears_at: Date()

    plugin:
      phpfpm:
        is_enbale: false

      nginx:
        sites: []

    resources_limit:
      cpu: 144
      storage: 520
      transfer: 39
      memory: 27

  tokens: [
    token: 'b535a6cec7b73a60c53673f434686e04972ccafddb2a5477f066f30eded55a9b'
    available: true
    created_at: Date()
    updated_at: Date()
    attribute:
      ip: '123.184.237.163'
      ua: 'Mozilla/5.0 (Intel Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.102'
  ]

exports.sha256 = (data) ->
  return null unless data
  return crypto.createHash('sha256').update(data).digest('hex')

exports.randomSalt = ->
  return exports.sha256 crypto.randomBytes 256

exports.hashPassword = (password, password_salt) ->
  return exports.sha256(exports.sha256(password) + password_salt)

exports.register = (username, email, password, callback) ->
  password_salt = exports.randomSalt()
  blockchain_secret = exports.randomSalt()

  bitcoin.genAddress blockchain_secret, (address) ->
    exports.insert
      _id: new ObjectID()
      username: username
      password: exports.hashPassword(password, password_salt)
      password_salt: password_salt
      email: email
      signup_at: new Date()
      group: []
      setting:
        avatar_url: "//ruby-china.org/avatar/#{crypto.createHash('md5').update(email).digest('hex')}?s=58"
      attribute:
        bitcoin_deposit_address: address
        blockchain_secret: blockchain_secret
        services: []
        plans: []
        balance: 0
        last_billing_at: new Date()
        arrears_at: null
        resources_limit: []

        plugin: {}
      tokens: []
    , (err, result) ->
      callback err, result?[0]

exports.updatePassword = (account, password, callback) ->
  password_salt = exports.randomSalt()

  exports.update _id: account._id,
    $set:
      password: exports.hashPassword(password, password_salt)
      password_salt: password_salt
  , callback

exports.createToken = (account, attribute, callback) ->
  generateToken = (callback) ->
    token = exports.randomSalt()

    exports.findOne
      'tokens.token': token
    , (err, result) ->
      if result
        generateToken callback
      else
        callback token

  generateToken (token) ->
    exports.update _id: account._id,
      $push:
        tokens:
          token: token
          available: true
          created_at: new Date()
          updated_at: new Date()
          attribute: attribute
    , ->
      callback null, token

exports.removeToken = (token, callback) ->
  exports.update {'tokens.token': token},
    $pull:
      tokens:
        token: token
  , callback

exports.authenticate = (token, callback) ->
  unless token
    return callback true, null

  exports.findOne
    'tokens.token': token
  , callback

exports.byUsernameOrEmailOrId = (username, callback) ->
  exports.byUsername username, (err, account) ->
    if account
      return callback null, account

    exports.byEmail username, (err, account) ->
      if account
        return callback null, account

      exports.findId username, (err, account) ->
        callback null, account

exports.matchPassword = (account, password) ->
  return exports.hashPassword(password, account.password_salt) == account.password

exports.inGroup = (account, group) ->
  return group in account.group

exports.joinPlan = (account, plan, callback) ->
  account.attribute.plans.push plan
  exports.update _id: account._id,
    $addToSet:
      'attribute.plans': plan
    $set:
      'attribute.resources_limit': exports.calcResourcesLimit account.attribute.plans
  , callback

exports.leavePlan = (account, plan, callback) ->
  account.attribute.plans = _.reject account.attribute.plans, (i) -> i == plan
  exports.update _id: account._id,
    $pull:
      'attribute.plans': plan
    $set:
      'attribute.resources_limit': exports.calcResourcesLimit account.attribute.plans
  , callback

exports.incBalance = (account, type, amount, attribute, callback) ->
  exports.update _id: account._id,
    $inc:
      'attribute.balance': amount
  , ->
    mBalance.create account, type, amount, attribute, (err, balance_log) ->
      callback balance_log

exports.calcResourcesLimit = (plans) ->
  limit = {}

  for plan in plans
    for k, v of config.plans[plan].resources
      limit[k] = 0 unless limit[k]
      limit[k] += v

  return limit
