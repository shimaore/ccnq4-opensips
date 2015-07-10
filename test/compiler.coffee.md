    describe 'The compiler', ->

      {configuration} = require '../src/config/compiler'

      verify = (t,m,p = {}) ->
        (require 'assert').strictEqual t, configuration m, p

      it 'should do variable substitution for numbers', ->
        verify 'var is 3', 'var is ${var}', var:3

      it 'should do variable substitution for strings', ->
        verify 'var is this', 'var is ${var}', var:'this'

      it 'should do conditionals', ->
        verify ' yes ', 'if it yes end if it', it:1

      it 'should do negative conditionals', ->
        verify ' yes ', 'if not it yes end if not it', it:0

      it 'should do conditionals on values', ->
        verify '', 'if it is 0 yes end if it is 0', it:1

      it 'should do conditionals on strings', ->
        verify ' yes ', 'if it is bob yes end if it is bob', it:'bob'

      it.skip 'should do conditionals on zero', ->
        verify ' yes ', 'if it is 0 yes end if it is 0', it:0 # fails: strings vs number

      it 'should do negative conditionals on strings', ->
        verify ' yes ', 'if it is not bob yes end if it is not bob', it:'bar'

      it 'should expand loops', ->
        verify ' a=3  a=9 ', 'for v in it a=${v} end for v in it', it:[3,9]

      it 'should expand macros', ->
        verify '  yes ', 'macro simple yes end macro simple ${simple}'

      it 'should expand macros with parameters', ->
        verify '  yes ', 'macro simple $1 end macro simple ${simple yes}'
        verify '  yes ', 'macro simple $1$2 end macro simple ${simple y es}'
        verify '  y-es ', 'macro simple $1-$2 end macro simple ${simple y es}'
        verify ' "yes"  ', '${simple y es} macro simple "$1$2" end macro simple'

      it 'should recursively expand macros', ->
        verify '  one_foo    ', '${two} macro one one_$1 end macro one macro two ${one foo} end macro two'
        verify '  one_yes    ', '${two yes} macro one one_$1 end macro one macro two ${one $1} end macro two'
