define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/replacer', [
  'cs!octokit-part/types'
], (types) ->

  # require('underscore-plus')
  plus =
    camelize: (string) ->
      if string
        string.replace /[_-]+(\w)/g, (m) -> m[1].toUpperCase()
      else
        ''


  TESTABLE_TYPES = (val for key, val of types)

  class Replacer
    constructor: (@_request) ->

    replace: (o) ->
      if Array.isArray(o)
        return @_replaceArray(o)
      else if o == Object(o)
        return @_replaceObject(o)
      else
        return o

    _replaceObject: (orig) ->
      acc = {}
      for key, value of orig
        @_replaceKeyValue(acc, key, value)

      for Type in TESTABLE_TYPES
        return new Type(@_request, acc) if Type::_test(acc)
      acc

    _replaceArray: (orig) ->
      return (@replace(item) for item in orig)

    # Convert things that end in `_url` to methods which return a Promise
    _replaceKeyValue: (acc, key, value) ->
      if /_url$/.test(key)
        fn = () =>
          # url can contain {name} or {/name} in the URL.
          # for every arg passed in, replace {...} with that arg
          # and remove the rest (they may or may not be optional)
          i = 0
          while m = /(\{[^\}]+\})/.exec(value)
            # `match` is something like `{/foo}`
            match = m[1]
            if i++ < arguments.length
              # replace it
              param = arguments[i]
              param = "/#{param}" if match[1] = '/'
            else
              # Discard the remaining optional params in the URL
              param = ''
              if match[1] != '/'
                throw new Error("BUG: Missing required parameter #{match}")
            value = value.replace(match, param)

          @_request('GET', value, null) # TODO: Heuristically set the isBoolean flag
        fn.url = value
        newKey = key.substring(0, key.length-'_url'.length)
        acc[plus.camelize(newKey)] = fn

      else if /_at$/.test(key)
        acc[plus.camelize(key)] = new Date(value)

      else
        acc[plus.camelize(key)] = @replace(value)



  module?.exports = Replacer
  return Replacer