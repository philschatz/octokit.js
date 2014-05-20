define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/chainer', [
  'cs!octokit-part/grammar'
  'cs!octokit-part/plus'
], ({TREE_OPTIONS, OBJECT_MATCHER, URL_VALIDATOR}, plus) ->

  # Converts a dictionary to a query string.
  # Internal helper method
  toQueryString = (options) ->

    # Returns '' if `options` is empty so this string can always be appended to a URL
    return '' if not options or options is {}

    params = []
    for key, value of options or {}
      params.push "#{key}=#{encodeURIComponent(value)}"
    return "?#{params.join('&')}"


  # Test if the path is constructed correctly
  tester = (path) ->
    unless URL_VALIDATOR.test(path)
      err = "BUG: Invalid Path. If this is actually a valid path then please update the URL_VALIDATOR. path=#{path}"
      console.warn(err)


  Chainer = (request, _path, contextTree, fn) ->
    fn ?= (args...) ->
      throw new Error('BUG! must be called with at least one argument') unless args.length
      return Chainer(request, "#{_path}/#{args.join('/')}", contextTree)

    for name of contextTree or {}
      do (name) ->
        fn.__defineGetter__ plus.camelize(name), () ->
          return Chainer(request, "#{_path}/#{name}", contextTree[name])

    fn.fetch        = (config) ->   tester(_path); request('GET', "#{_path}#{toQueryString(config)}")
    fn.read         = () ->         tester(_path); request('GET', _path, null, raw:true)
    fn.readBinary   = () ->         tester(_path); request('GET', _path, null, raw:true, isBase64:true)
    fn.remove       = () ->         tester(_path); request('DELETE', _path, null, isBoolean:true)
    fn.create       = (config, isRaw) ->   tester(_path); request('POST', _path, config, raw:isRaw)
    fn.update       = (config) ->   tester(_path); request('PATCH', _path, config)
    fn.add          = () ->         tester(_path); request('PUT', _path, null, isBoolean:true)
    fn.contains     = (args...) ->  tester(_path); request('GET', "#{_path}/#{args.join('/')}", null, isBoolean:true)

    toCallback = (fnName) ->
      orig = fn[fnName]
      fn[fnName] = (args...) ->
        last = args[args.length - 1]
        if typeof last is 'function'
          cb = args.pop()
          promise = orig(args...)
          return promise.then ((val) -> cb(null, val)), ((err) -> cb(err))
        else
          return orig(args...)

    toCallback(name) for name in ['fetch', 'read', 'readBinary', 'remove', 'create', 'update', 'add', 'contains']

    return fn


  module?.exports = Chainer
  return Chainer
