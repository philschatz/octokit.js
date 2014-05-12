@define ?= (name, deps, cb) -> cb (require(dep) for dep in deps)...
@define 'octokit', [
  './replacer'
  './request'
  './types'
  './helper-promise'
], (Replacer, Request, {Me}, {newPromise, allPromises}) ->

  # Combine all the classes into one client

  Octokit = (clientOptions={}) ->

    # For each request, convert the JSON into Objects
    _request = Request(clientOptions)

    request = (method, path, data, options={raw:false, isBase64:false, isBoolean:false}) ->

      replacer = new Replacer(request)

      return _request(arguments...)
      .then (val) ->
        return val if options.raw
        return replacer.replace(val)


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

    issues: (config) -> request('GET', '/issues', config)



  module?.exports = Octokit
  return Octokit
