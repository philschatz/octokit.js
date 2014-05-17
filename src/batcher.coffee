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


  URL_VALIDATOR = /// ^

    (https?://[^/]+)? # Optional protocol, host, and port
    (/api/v3)?        # Optional API root for enterprise GitHub users

    / (
        zen
      | users
      | issues
      | gists
      | emojis
      | meta
      | rate_limit
      | feeds
      | gitignore/templates (/[^/]+)?

      | user/ (
          repos
        | orgs
        | followers
        | following (/[^/]+)?
        | emails    (/[^/]+)?
        | issues
        | starred   (/[^/]+){0,2}
      )

      | orgs/  [^/]+
      | orgs/  [^/]+ / (
            repos
          | issues
          | members
        )


      | users/ [^/]+
      | users/ [^/]+ / (
            repos
          | orgs
          | gists
          | followers
          | following (/[^/]+){0,2}
          | keys
          | events
          | received_events
        )


      | search/ (
            repositories
          | issues
          | users
          | code
        )


      | gists/ (
            public
          | [a-f0-9]{20} (/star)?
          | [0-9]+       (/star)?
        )


      | repos (/[^/]+){2}
      | repos (/[^/]+){2} / (
            hooks
          | assignees
          | branches
          | contributors
          | subscribers
          | subscription
          | comments
          | downloads
          | milestones
          | labels
          | collaborators (/[^/]+)?
          | issues
          | issues/ (
                events
              | comments (/[0-9]+)?
              | [0-9]+ (/comments)?
              )

          | git/ (
                refs (/heads)?
              | trees (/[a-f0-9]{40}$)?
              | blobs (/[a-f0-9]{40}$)?
            )
          | stats/ (
                contributors
              | commit_activity
              | code_frequency
              | participation
              | punch_card
            )
        )
    )
    $
  ///



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

    # From https://developer.github.com/v3/repos/releases/
    'releases'
    'assets'

    # From https://developer.github.com/v3/repos/statistics/
    'stats'
    'commit_activity'
    'code_frequency'
    'participation'
    'punch_card'


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
