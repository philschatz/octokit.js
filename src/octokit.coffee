define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit', [
  'cs!octokit-part/replacer'
  'cs!octokit-part/request'
  'cs!octokit-part/types'
  'cs!octokit-part/helper-promise'
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

    # Converts a dictionary to a query string.
    # Internal helper method
    toQueryString = (options) ->

      # Returns '' if `options` is empty so this string can always be appended to a URL
      return '' if not options or options is {}

      params = []
      for key, value of options or {}
        params.push "#{key}=#{encodeURIComponent(value)}"
      return "?#{params.join('&')}"


    global:
      zen: () -> request('GET', '/zen', null, raw:true)
      users: (config) -> request('GET', '/users', config)
      gists: (config) -> request('GET', '/gists/public', config)
      events: (config) -> request('GET', '/events', config)
      notifications: (config) -> request('GET', '/notifications', config)

    search:
      repos:  (config) -> request('GET', "/search/repositories#{toQueryString(config)}")
      code:   (config) -> request('GET', "/search/code#{toQueryString(config)}")
      issues: (config) -> request('GET', "/search/issues#{toQueryString(config)}")
      users:  (config) -> request('GET', "/search/users#{toQueryString(config)}")

    me: new Me(request)
    user: (id) -> request('GET', "/users/#{id}")
    team: (id) -> request('GET', "/teams/#{id}")
    org:  (id) -> request('GET', "/orgs/#{id}")
    repo: (user, name) -> request('GET', "/repos/#{user}/#{name}")
    gist: (id) -> request('GET', "/gists/#{id}")

    gists:
      all: () -> request('GET', '/gists/public')
      create: (options) -> request('POST', '/gists', options)

    issues: (config) -> request('GET', '/issues', config)



  module?.exports = Octokit
  window?.Octokit = Octokit
  return Octokit
