async = require 'async'
clone = require 'clone'

config = require '../config'

Account = require '../model/Account'
Ticket = require '../model/Ticket'

module.exports =
  get:
    list: (req, res) ->
      Account.authenticate req.token, (account) ->
        unless account
          return res.redirect '/account/login/'

        Ticket.find
          account_id: account.id()
        , (tickets) ->
          res.render 'ticket/list',
            account: account
            tickets: tickets

    create: (req, res) ->
      Account.authenticate req.token, (account) ->
        unless account
          return res.redirect '/account/login/'

        res.render 'ticket/create',
          account: account
          ticketTypes: config.ticket.availableType

  post:
    create: (req, res) ->
      Account.authenticate req.token, (account) ->
        unless account
          return res.json 400, error: 'auth_failed'

        data = req.body

        unless /^.+$/.test data.title
          return res.json 400, error: 'invalid_title'

        unless data.type in config.ticket.availableType
          return res.json 400, error: 'invalid_type'

        createTicket = (members) ->
          Ticket.createTicket account, data.title, data.content, data.type, members, {}, (ticket) ->
            return res.json
              id: ticket.id()

        if account.inGroup 'root'
          tasks = []

          if data.members
            for memberName in data.members
              do (memberName = clone(memberName)) ->
                tasks.push (callback) ->
                  Account.byUsernameOrEmail memberName, (member) ->
                    unless member
                      res.json 400, error: 'invalid_account', username: memberName
                      callback true

                    callback null, member

            async.parallel tasks, (err, result) ->
              if err
                return

              unless _.find(result, (item) -> item.id() == account.id())
                result.push account

              createTicket result

        else
          createTicket [account]

    reply: (req, res) ->
      Account.authenticate req.token, (account) ->
        unless account
          return res.json 400, error: 'auth_failed'

        data = req.body

        Ticket.findById data.id, (ticket) ->
          checkReplyTo = (callback) ->
            if data.reply_to
              Ticket.findOne
                'replys._id': data.reply_to
              , (result) ->
                if result
                  callback null
                else
                  callback true
            else
              callback null

          checkReplyTo (err) ->
            if err
              return res.json 400, error: 'reply_not_exist'

            unless ticket.hasMember account
              unless account.inGroup 'root'
                return res.json 400, error: 'forbidden'

            ticket.createReply account, reply_to, content, (reply) ->
              return res.json
                id: reply._id

    update: (req, res) ->
