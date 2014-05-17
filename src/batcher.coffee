define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/batcher', ['cs!octokit-part/plus'], (plus) ->

  # Converts a dictionary to a query string.
  # Internal helper method
  toQueryString = (options) ->

    # Returns '' if `options` is empty so this string can always be appended to a URL
    return '' if not options or options is {}

    params = []
    for key, value of options or {}
      params.push "#{key}=#{encodeURIComponent(value)}"
    return "?#{params.join('&')}"


  ALL_NOUNS = [
    # Global
    'repositories'
    'code'
    'users'
    # User
    'repos'
    'orgs'
    'gists'
    'followers'
    'starred'
    'following'
    'keys'
    'events'
    'received_events'
    'public'
    # Me
    'emails'
    'issues'
    # Team
    'members'
    'teams'
    # Repo
    'laguages'
    'releases'
    'stargazers'
    'forks'
    'pulls'
    'issues'
    'comments'
    'notifications'
    'collaborators'
    'assignees'
    'hooks'
    'contents'
    'git'
    'commits'
    'refs'
    'tags'
    'heads'
    'blobs'
    'trees'
    # Repo (autogen from JSON URL Patterns)
    'branches'
    'contributors'
    'subscribers'
    'subscription'
    'downloads'
    'milestones'
    'labels'

    # From https://developer.github.com/v3/repos/pages/
    'pages'
    'builds'
    'latest'

    # Gist
    'star'

    # From the global
    'templates' # for /gitignore/templates
    'raw'       # for /markdown/raw

  ]

  Batcher = (request, path, fn) ->
    fn ?= (args...) ->
      throw new Error('BUG! must be called with at least one argument') unless args.length
      return Batcher(request, "#{path}/#{args.join('/')}")

    for name in ALL_NOUNS
      do (name) ->
        fn.__defineGetter__ plus.camelize(name), () ->
          return Batcher(request, "#{path}/#{name}")

    fn.fetch        = (config) ->   request('GET', "#{path}#{toQueryString(config)}")
    fn.read         = () ->         request('GET', path, null, raw:true)
    fn.readBinary   = () ->         request('GET', path, null, raw:true, isBase64:true)
    fn.remove       = () ->         request('DELETE', path, null, isBoolean:true)
    fn.create       = (config, isRaw) ->   request('POST', path, config, raw:isRaw)
    fn.update       = (config) ->   request('PATCH', path, config)
    fn.add          = (args...) ->  request('PUT', path, null, isBoolean:true)
    fn.contains     = (args...) ->  request('GET', "#{path}/#{args.join('/')}", null, isBoolean:true)

    return fn


  module?.exports = Batcher
  return Batcher
