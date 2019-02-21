    chai = require 'chai'
    chai.should()
    describe 'Config', ->
      it 'should set defaults for client', ->
        process.env.CONFIG = JSON.stringify prefix_admin:'foo'
        build_config = require '../config'
        config = build_config opensips:
          model:'client'
          foo:42
        config.should.have.property 'db_url', 'http://127.0.0.1:34340/'
        config.should.have.property 'mp_allowed', 1
        config.should.have.property 'foo', 42
        config.should.not.have.property 'uac_hash_size'
        delete process.env.CONFIG
      it 'should set defaults for registrant', ->
        process.env.CONFIG = JSON.stringify prefix_admin:'foo'
        build_config = require '../config'
        config = build_config opensips:
          model:'registrant'
          foo:43
        config.should.have.property 'db_url', 'http://127.0.0.1:34340/'
        config.should.have.property 'uac_hash_size', 3
        config.should.have.property 'foo', 43
        delete process.env.CONFIG
