@define ?= (name, deps, cb) -> cb (require(dep) for dep in deps)...
@define 'octokit', [
  './replacer'
  './request'
  './types'
], (Replacer, RequestTemplate, {Me}) ->

  # Combine all the classes into one client

  octokitClient = (request) ->

    global:
      zen: () -> request('GET', '/zen', null, raw:true)
      users: (config) -> request('GET', '/users', config)
      gists: (config) -> request('GET', '/gists', config)
      events: (config) -> request('GET', '/events', config)
      notifications: (config) -> request('GET', '/notifications', config)

    search:
      repos:  (config) -> request('GET', '/search/repositories', config)
      code:   (config) -> request('GET', '/search/code', config)
      issues: (config) -> request('GET', '/search/issues', config)
      users:  (config) -> request('GET', '/search/users', config)

    me: new Me(request)
    user: (id) -> request('GET', "/users/#{id}")
    team: (id) -> request('GET', "/teams/#{id}")
    org:  (id) -> request('GET', "/orgs/#{id}")
    repo: (user, name) -> request('GET', "/repos/#{user}/#{name}")
    gist: (id) -> request('GET', "/gists/#{id}")
    gists:
      fetch: () -> request('GET', '/gists')
      create: (options) -> request('POST', '/gists', options)
      remove: (id) -> request('DELETE', "/gists/#{id}")



  # # Create a Client Constructor
  # These args will vary depending on if it is used in NodeJS or in the browser
  # and which promise library is used.

  makeOctokit = (newPromise, allPromises, XMLHttpRequest, base64encode, userAgent) =>

    Request = RequestTemplate(newPromise, allPromises, XMLHttpRequest, base64encode, userAgent)

    return (clientOptions={}) ->

      # For each request, convert the JSON into Objects
      _request = Request(clientOptions)

      request = (method, path, data, options={raw:false, isBase64:false, isBoolean:false}) ->

        replacer = new Replacer(request)

        return _request(arguments...)
        .then (val) ->
          return replacer.replace(val) unless options.raw
          return val

      return octokitClient(request)



  # Use native promises if Harmony is on
  Promise         = @Promise or require('es6-promise').Promise
  XMLHttpRequest  = require('xmlhttprequest').XMLHttpRequest

  newPromise = (fn) -> return new Promise(fn)
  allPromises = (promises) -> return Promise.all(promises)
  # Encode using native Base64
  encode = (str) ->
    buffer = new Buffer(str, 'binary')
    return buffer.toString('base64')
  Octokit = makeOctokit(newPromise, allPromises, XMLHttpRequest, encode, 'octokit') # `User-Agent` (for nodejs)


  module?.exports = Octokit
  return Octokit
