define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/types', [
  'cs!octokit-part/helper-base64'
], (base64encode) ->


  methodGenerator = (request, rootUrl, context, config) ->
    for name, methodConfig of config
      do (name, methodConfig) ->
        if typeof methodConfig is 'function'
          context[name] = methodConfig(request, rootUrl)
        else
          {verb, url, urlSuffix, urlArgs, urlSeparator, hasQueryArg, hasDataArg, raw, isBase64, isBoolean, children} = methodConfig
          url ?= ''
          verb ?= 'NONE'
          urlArgs ?= []
          urlSeparator ?= '/'
          urlSuffix ?= ''

          options = {raw, isBase64, isBoolean}

          if url and url[0] isnt '/'
            url = "#{rootUrl}/#{url}"
          else
            url = rootUrl

          url = "#{url}#{urlSuffix}"

          myRoot = url

          if verb is 'NONE'
            context[name] = {}
          else
            context[name] = (args...) ->
              myUrl = url
              for argName, i in urlArgs
                if args.length
                  myUrl += "#{urlSeparator}#{args.shift()}"

              if hasQueryArg and args.length
                myUrl += toQueryString(args.shift())

              data = null
              if hasDataArg and args.length
                data = args.shift()

              request(verb, myUrl, data, options)

          # Recurse on children
          methodGenerator(request, myRoot, context[name], methodConfig.children) if methodConfig.children



  class Base
    _test: () -> throw new Error('BUG: Unimplemented method')
    constructor: (request, json) ->
      # json is the response JSON from GitHub
      for key, val of json
        @[key] = val

      @fetch = () => request('GET', @url)

      methodGenerator(request, @url, @, @_autogen) if @_autogen


  class User extends Base
    _test: (obj) -> obj.type is 'User'
    _autogen:
      'repos':      verb: 'GET', url: 'repos', hasDataArg: true
      'orgs':       verb: 'GET', url: 'orgs'
      'gists':      verb: 'GET', url: 'gists'
      'followers':  verb: 'GET', url: 'followers'

      'starred':
        verb: 'GET'
        url: 'starred'
        children:
          'all': verb: 'GET'

      'following':
        url: 'following'
        children:
          'all':  verb: 'GET'
          'is':   verb: 'GET', urlArgs: ['id'], isBoolean: true

      'keys':           verb: 'GET', url: 'keys'
      'events':         verb: 'GET', url: 'events'
      'receivedEvents': verb: 'GET', url: 'received_events'
      'eventsPublic':   verb: 'GET', url: 'events/public'
      'receivedEventsPublic': verb: 'GET', url: 'received_events/public'



  class Me extends Base
    _test: () -> false
    _autogen:
      'repos':      verb: 'GET', url: 'repos', hasDataArg: true
      'orgs':       verb: 'GET', url: 'orgs'
      'followers':  verb: 'GET', url: 'followers'

      'starred':
        url: 'starred'
        children:
          'all':    verb: 'GET',    hasDataArg: true
          'is':     verb: 'GET',    urlArgs: ['user', 'optionalname'], isBoolean: true
          'add':    verb: 'PUT',    urlArgs: ['user', 'optionalname'], isBoolean: true
          'remove': verb: 'DELETE', urlArgs: ['user', 'optionalname'], isBoolean: true

      # Specific to Authenticated user
      'following':
        url: 'following'
        children:
          'all':    verb: 'GET'
          'is':     verb: 'GET',    urlArgs: ['id'], isBoolean: true
          'add':    verb: 'PUT',    urlArgs: ['id'], isBoolean: true
          'remove': verb: 'DELETE', urlArgs: ['id'], isBoolean: true

      'emails':
        url: 'emails'
        children:
          'all':    verb: 'GET'
          'is':     verb: 'GET',    urlArgs: ['id'], isBoolean: true
          'add':    verb: 'PUT',    urlArgs: ['id'], isBoolean: true
          'remove': verb: 'DELETE', urlArgs: ['id'], isBoolean: true

      # 'keys':
      #   url: 'keys'
      #   children:
      #     'all':    verb: 'GET'
      #     'one':    verb: 'GET',    urlArgs: ['id']
      #     'is':     verb: 'GET',    urlArgs: ['id'], isBoolean: true
      #     'add':    verb: 'PUT',    urlArgs: ['id'], isBoolean: true
      #     'remove': verb: 'DELETE', urlArgs: ['id'], isBoolean: true

      'issues': url: 'issues', verb: 'GET', hasDataArg: true

    constructor: (request) ->
      super(request, {url:'/user'})


  class Team extends Base
    _test: (obj) -> /\/teams\//.test(obj.url)
    _autogen:
      'update': verb: 'PATCH', hasDataArg: true
      'remove': verb: 'DELETE'
      'members':
        url: 'members'
        children:
          'all': verb: 'GET'
          'is':
            verb: 'GET'
            urlArgs: ['id']
            isBoolean: true
          'add':
            verb: 'PUT'
            urlArgs: ['id']
            isBoolean: true
          'remove':
            verb: 'DELETE'
            urlArgs: ['id']
            isBoolean: true

      'repos':
        url: 'repos'
        'all': verb: 'GET'
        children:
          'add':    verb: 'PUT',    urlArgs: ['repoUser', 'repoName'], isBoolean: true
          'remove': verb: 'DELETE', urlArgs: ['repoUser', 'repoName'], isBoolean: true


  class Org extends Base
    _test: (obj) -> /\/orgs\//.test(obj.url)
    _autogen:
      'update': verb: 'PATCH', hasDataArg: true
      'remove': verb: 'DELETE'
      'teams':
        url: 'teams'
        children:
          'all':    verb: 'GET'
          'create': verb: 'POST', hasDataArg: true

      'members':
        url: 'members'
        children:
          'all': verb: 'GET'
          'is':
            verb: 'GET'
            urlArgs: ['id']
            isBoolean: true
          'add':
            verb: 'PUT'
            urlArgs: ['id']
            isBoolean: true
          'remove':
            verb: 'DELETE'
            urlArgs: ['id']
            isBoolean: true

      'repos':
        url: 'repos'
        children:
          'all':    verb: 'GET'
          'create': verb: 'POST', urlArgs: ['repoName']

      'issues': verb: 'GET', url: 'issues'


  class Repo extends Base
    _test: (obj) -> /\/repos\/[^\/]+\/[^\/]+$/.test(obj.url)
    _autogen:
      'update': verb: 'PATCH', hasDataArg: true
      'remove': verb: 'DELETE'

      'languages':  verb: 'GET', url: 'languages'
      'releases':   verb: 'GET', url: 'releases'
      'stargazers':   verb: 'GET', url: 'stargazers'

      'forks':
        url: 'forks'
        children:
          'all':    verb: 'GET'
          'create': verb: 'POST', hasDataArg: true

      'pulls':
        url: 'pulls'
        children:
          'all':    verb: 'GET'
          'create': verb: 'POST', hasDataArg: true

      'issues':
        url: 'issues'
        children:
          'all': verb: 'GET'
          'one': verb: 'GET', urlArgs: ['id']
          'create': verb: 'POST', hasDataArg: true
          'events': verb: 'GET', url: 'events'
          'comments':
            url: 'comments'
            children:
              'all': verb: 'GET'
              'one': verb: 'GET', urlArgs: ['commentId']

      'notifications': verb: 'GET', url: 'notifications', hasDataArg: true

      'collaborators':
        url: 'collaborators'
        children:
          'all': verb: 'GET'
          'is':
            verb: 'GET'
            urlArgs: ['id']
            isBoolean: true
          'add':
            verb: 'PUT'
            urlArgs: ['id']
            isBoolean: true
          'remove':
            verb: 'DELETE'
            urlArgs: ['id']
            isBoolean: true

      'assignees':
        url: 'assignees'
        children:
          'all':  verb: 'GET'
          'is':   verb: 'GET', urlArgs: ['userId'], isBoolean: true

      'hooks':
        url: 'hooks'
        children:
          'all': verb: 'GET'
          'create': verb: 'POST', hasDataArg: true
          # TODO: Should there be a Hook class?
          'update': verb: 'PATCH', urlArgs: ['hookId'], hasDataArg: true
          'remove': verb: 'DELETE', urlArgs: ['hookId']
          'test':   verb: 'POST', urlSuffix: '/tests', urlArgs: ['hookId']

      'contents':
        url: 'contents'
        read:   verb: 'GET',    urlArgs: ['path'], hasQueryArg: true, raw: true
        remove: verb: 'DELETE', urlArgs: ['path'], hasDataArg: true


      'git':
        url: 'git'
        children:
          'commits':
            url: 'commits'
            children:
              'all':    verb: 'GET'
              'create': verb: 'POST', hasDataArg: true
          'refs':
            url: 'refs'
            children:
              'all':    verb: 'GET'
              'one':    verb: 'GET',  urlArgs: ['refId']
              'create': verb: 'POST', hasDataArg: true
              'remove': verb: 'DELETE', urlArgs: ['refId']
              'update': verb: 'PATCH',  urlArgs: ['refId']

              'tags':   verb: 'GET', url: 'tags'
              'heads':  verb: 'GET', url: 'heads'

          'tags':
            url: 'tags'
            children:
              'one':    verb: 'GET', urlArgs: ['tagName']
              'create': verb: 'POST', hasDataArg: true

          'blobs':
            url: 'blobs'
            children:
              'create': (request, rootUrl) ->
                (content, isBase64) ->
                  if typeof content is 'string'
                    # Base64 encode the content if it is binary (isBase64)
                    content = base64encode(content) if isBase64 is true
                    content =
                      content: content
                      encoding: 'utf-8'
                  content.encoding = 'base64' if isBase64 is true
                  request('POST', rootUrl, content)
                  # TODO: .then (val) => val.sha
              'one': (request, rootUrl) ->
                (sha, isBase64) ->
                  request 'GET', "#{rootUrl}/#{sha}", null, raw: true, isBase64: isBase64 is true

          'trees':
            url: 'trees'
            children:
              'one': verb: 'GET', urlArgs: ['sha'], hasQueryArg: true # {recursive: 1}
              'create': verb: 'POST', hasDataArg: true


  class Gist extends Base
    _test: (obj) -> /\/gists\//.test(obj.url)

    _autogen:
      'update': verb: 'PATCH', hasDataArg: true
      'remove': verb: 'DELETE'

      'forks':
        url: 'forks'
        children:
          # 'all':    verb: 'GET'
          'create': verb: 'POST', hasDataArg: true

      'starred':
        url: 'star'
        children:
          # 'all':    verb: 'GET', hasQueryArg: true
          'is':     verb: 'GET', isBoolean: true
          'add':    verb: 'PUT', isBoolean: true
          'remove': verb: 'DELETE', isBoolean: true


  class Issue extends Base
    _test: (obj) -> /\/repos\/[^\/]+\/[^\/]+\/issues\/[^\/]+$/.test(obj.url) or
                    /\/repos\/[^\/]+\/[^\/]+\/pulls\/[^\/]+$/.test(obj.url)
    _autogen:
      'update': verb: 'PATCH', hasDataArg: true
      'comments':
        url: 'comments'
        children:
          'all':    verb: 'GET'
          'one':    verb: 'GET',    urlArgs: ['commentId']
          'create': verb: 'POST',   hasDataArg: true
          'update': verb: 'PATCH',  urlArgs: ['commentId'], hasDataArg: true
          'remove': verb: 'DELETE', urlArgs: ['commentId']

  class Event extends Base
    _test: (obj) -> obj.type in ['PushEvent', 'MemberEvent']
    constructor: (request, json) ->
      super

  types = {User, Me, Team, Org, Repo, Gist, Issue, Event}

  module?.exports = types
  return types
