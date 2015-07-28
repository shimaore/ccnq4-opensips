    chai = require 'chai'
    chai.use require 'chai-as-promised'
    chai.should()

    request = (require 'superagent-as-promised') require 'superagent'

    describe "munin", ->
      @timeout 4000
      it 'should return proper autoconf', (done) ->
        munin = require '../src/munin'
        {server} = munin {}
        server.on 'listening', ->
          request
          .get 'http://127.0.0.1:3939/autoconf'
          .then ({text}) ->
            text.should.equal 'yes\n'
            done()

      it 'should return config', (done) ->
        munin = require '../src/munin'
        {server} = munin munin: port:3940
        server.on 'listening', ->
          request
          .get 'http://127.0.0.1:3940/config'
          .then ({text}) ->
            text.should.match /opensips_registrar_accepted/
            done()
