define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit', [
  'cs!octokit-part/plus'
  'cs!octokit-part/grammar'
  'cs!octokit-part/batcher'
  'cs!octokit-part/replacer'
  'cs!octokit-part/request'
  'cs!octokit-part/helper-promise'
], (plus, {TREE_OPTIONS, OBJECT_MATCHER}, Batcher, Replacer, Request, {newPromise, allPromises}) ->

  # Combine all the classes into one client

  Octokit = (clientOptions={}) ->

    # For each request, convert the JSON into Objects
    _request = Request(clientOptions)

    request = (method, path, data, options={raw:false, isBase64:false, isBoolean:false}) ->
      replacer = new Replacer(request)

      data = replacer.dasherize(data) if data

      return _request(method, path, data, options)
      .then (val) ->
        return val if options.raw
        obj = replacer.replace(val)
        for key, re of OBJECT_MATCHER
          Batcher(request, obj.url, TREE_OPTIONS[key], obj) if re.test(obj.url)
        return obj

    path = ''
    obj = {}
    Batcher(request, path, TREE_OPTIONS, obj)

    # Special case for `me`
    obj.me = obj.user
    delete obj.user


    return obj


  module?.exports = Octokit
  window?.Octokit = Octokit
  return Octokit
