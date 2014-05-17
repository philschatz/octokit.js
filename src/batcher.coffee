define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/batcher', [
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


  Batcher = (request, path, contextTree, fn) ->
    fn ?= (args...) ->
      throw new Error('BUG! must be called with at least one argument') unless args.length
      return Batcher(request, "#{path}/#{args.join('/')}", contextTree)

    for name of contextTree or {}
      do (name) ->
        fn.__defineGetter__ plus.camelize(name), () ->
          return Batcher(request, "#{path}/#{name}", contextTree[name])

    # Test if the path is constructed correctly
    tester = (path) ->
      unless URL_VALIDATOR.test(path)
        throw new Error('BUG: Invalid Path. If this is an error then please update the URL_VALIDATOR')


    fn.fetch        = (config) ->   tester(path); request('GET', "#{path}#{toQueryString(config)}")
    fn.read         = () ->         tester(path); request('GET', path, null, raw:true)
    fn.readBinary   = () ->         tester(path); request('GET', path, null, raw:true, isBase64:true)
    fn.remove       = () ->         tester(path); request('DELETE', path, null, isBoolean:true)
    fn.create       = (config, isRaw) ->   tester(path); request('POST', path, config, raw:isRaw)
    fn.update       = (config) ->   tester(path); request('PATCH', path, config)
    fn.add          = (args...) ->  tester(path); request('PUT', path, null, isBoolean:true)
    fn.contains     = (args...) ->  tester(path); request('GET', "#{path}/#{args.join('/')}", null, isBoolean:true)

    return fn


  module?.exports = Batcher
  return Batcher
