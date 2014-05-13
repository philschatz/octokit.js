define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/types', [], () ->


  # Utility classes for various containerish calls:
  # like `following`, `members`, `collaborators`, `keys`, `emails`, `git.commits`, `stars`
  Createable = (request, root) ->
    fn = () -> request('GET', root)
    fn.create = (config) -> request('POST', root, config)
    fn


  Addable = (request, root) ->
    fn = () -> request('GET', root)
    fn.add    = (id) -> request('PUT', "#{root}/#{id}", null, isBoolean:true)
    fn.remove = (id) -> request('DELETE', "#{root}/#{id}", null, isBoolean:true)
    fn

  Isable = (fn, request, root) ->
    throw new Error("BUG: Missing function for #{root}") if not fn
    fn.add    = (id) -> request('PUT', "#{root}/#{id}", null, isBoolean:true)
    fn.remove = (id) -> request('DELETE', "#{root}/#{id}", null, isBoolean:true)

  Toggle = (fn, request, root) ->
    throw new Error("BUG: Missing function for #{root}") if not fn
    fn.add    = () -> request('PUT', root, null, isBoolean:true)
    fn.remove = () -> request('DELETE', root, null, isBoolean:true)






  class Base
    _test: () -> throw new Error('BUG: Unimplemented method')
    constructor: (request, json) ->
      # json is the response JSON from GitHub
      for key, val of json
        @[key] = val

      @fetch = () => request('GET', @url)



  class User extends Base
    _test: (obj) -> obj.type is 'User'
    constructor: (request, json) ->
      super
      @repos      = (config) => request('GET', "#{@url}/repos", config)
      @orgs       = (config) => request('GET', "#{@url}/orgs")
      @gists      = (config) => request('GET', "#{@url}/gists")
      @followers  = () => request('GET', "#{@url}/followers")
      @following = (id=null) =>
        return request('GET', "#{@url}/#{id}", null, isBoolean:true) if id
        return request('GET', @url)
      @keys = () => request('GET', "#{@url}/keys")

      @events = (onlyPublic) =>
        pub = ''
        pub = '/public' if onlyPublic is true
        request('GET', "#{@url}/events#{pub}")

      @receivedEvents = (onlyPublic) =>
        pub = ''
        pub = '/public' if onlyPublic is true
        request('GET', "#{@url}/received_events#{pub}")


  class Me extends User
    _test: () -> false
    constructor: (request) ->
      super(request, {url:'/user'})

      Isable(@following, request, "#{@url}/following")
      @emails    = Addable(request, "#{@url}/emails")
      @keys      = Addable(request, "#{@url}/keys")
      @key = (id) =>
        fetch: () => request('GET', "#{@url}/keys/#{id}")

      @issues = (config) => request('GET', "#{@url}/issues", config)

  class Team extends Base
    _test: (obj) -> /\/teams\//.test(obj.url)
    constructor: (request, json) ->
      super
      @update = (config) => request('PATCH', @url, config)
      @remove = () => request('DELETE', @url)

      Isable(@members, request, "#{@url}/members")

      @repositories.add =    (user, name) => request('PUT', "#{@url}/repos/#{user}/#{name}")
      @repositories.remove = (user, name) => request('DELETE', "#{@url}/repos/#{user}/#{name}")


  class Org extends Base
    _test: (obj) -> /\/orgs\//.test(obj.url)
    constructor: (request, json) ->
      super
      @update = (config) => request('PATCH', @url, config)
      @teams = Createable(request, "#{@url}/teams")
      Isable(@members, request, "#{@url}/members")
      @repos =
        fetch:  () => request('GET', "#{@url}/repos")
        create: (name) => request('POST', "#{@url}/repos/#{name}")

      @issues = (config) => request('GET', "#{@url}/issues", config)


  class Git
    _test: () -> false
    constructor: (request, root) ->
      @url = "#{root}/git"

      @commits = Createable(request, "#{@url}/git/commits")

      @refs =
        create: (config) => request('POST', "#{@url}/refs", config)
        remove: (id) => request('DELETE', "#{@url}/refs/#{id}")
      @ref = (id) =>
        fetch: () => request('GET', "#{@url}/refs/#{id}")

      @heads =
        fetch: () => request('GET', "#{@url}/heads")
      @head = (id) =>
        update: (config) => request('PATCH', "#{@url}/heads/#{id}", config)

      @blobs =
        create: (content, isBase64) =>
          if typeof content is 'string'
            # Base64 encode the content if it is binary (isBase64)
            content = base64encode(content) if isBase64 is true
            content =
              content: content
              encoding: 'utf-8'
          content.encoding = 'base64' if isBase64 is true
          request('POST', "#{@url}/blobs", content)
          # TODO: .then (val) => val.sha
      @blob = (id, isBase64) =>
        options =
          raw: true
          isBase64: isBase64 is true
        fetch: () => request('GET', "#{@url}/blobs/#{id}", null, options)

      @trees =
        create: (config) => request('POST', "#{@url}/trees", config)
      @tree = (id) =>
        fetch: () => request('GET', "#{@url}/trees/#{id}")


  class Repo extends Base
    _test: (obj) -> /\/repos\/[^\/]+\/[^\/]+$/.test(obj.url)
    constructor: (request, json) ->
      super

      @git = new Git(request, @url)

      @fetch = () => request('GET', @url)
      @update = (config) => request('PATCH', @url, config)
      # TODO: move remove out of here
      @remove = () => request('DELETE', @url)
      @forks = () => request('GET', "#{@url}/forks")
      @forks.create = (config) => request('POST', "#{@url}/forks", config)

      @pulls?.create = (config) => request('POST', "#{@url}/pulls", config)
      @issues = (config) =>
        if typeof config is 'number'
          return request('GET', "#{@url}/issues/#{config}")
        request('GET', "#{@url}/issues", config)
      @issues.events = () => request('GET', "#{@url}/issues/events")
      @issues.create = (config) => request('POST', "#{@url}/issues", config)
      @issues.update = (id, config) => request('PATCH', "#{@url}/issues/#{id}", config)

      # Network is slightly different because its @url is not `/repos/`
      @network =
        events: () => request('GET', "/networks/#{@owner.login}/#{@name}/events")
      @notifications = (config) => request('GET', "#{@url}/notifications", config)

      @collaborators = (id=null) =>
        return request('GET', "#{@url}/collaborators/#{id}", null, isBoolean:true) if id
        return request('GET', "#{@url}/collaborators")
      Isable(@collaborators, request, "#{@url}/collaborators")

      @hooks?.create = (config) => request('POST', "#{@url}/hooks", config)
      @hooks?.remove = (id) => request('DELETE', "#{@url}/hooks/#{id}")
      @hooks?.test   = (id) => request('POST', "#{@url}/hooks/#{id}/tests")
      @hooks?.update = (id, config) => request('PATCH', "#{@url}/hooks/#{id}", config)

      @contents = (path, sha) =>
        fetch: () =>
          queryString = toQueryString({ref:sha})
          request('GET', "#{@url}/contents/#{path}#{queryString}", null, raw:true)
        remove: (config) =>
          throw new Error('BUG: message is required') unless config.message
          config.sha = sha
          request('DELETE', "#{@url}/contents/#{path}", config)

      @languages = () => request('GET', "#{@url}/languages")
      @releases = () => request('GET', "#{@url}/releases")



  class Gist extends Base
    _test: (obj) -> /\/gists\//.test(obj.url)
    constructor: (request, json) ->
      super
      @fetch  = () => request('GET', @url)
      @update = (config) => request('PATCH', @url, config)
      @remove = () => request('DELETE', @url)

      @forks.create = () => request('POST', "#{@url}/forks")

      @starred = () => request('GET', "#{@url}/star", null, isBoolean:true)
      @starred.add    = () => request('PUT', "#{@url}/star", null, isBoolean:true)
      @starred.remove = () => request('DELETE', "#{@url}/star", null, isBoolean:true)


  class Issue extends Base
    _test: (obj) -> /\/repos\/[^\/]+\/[^\/]+\/issues\/[^\/]+$/.test(obj.url) or /\/repos\/[^\/]+\/[^\/]+\/pulls\/[^\/]+$/.test(obj.url)
    constructor: (request, json) ->
      super
      @update = (config) => request('PATCH', @url, config)
      @comments = Createable(request, "#{@url}/comments")
      @comments.update = (id, config) => request('PATCH', "#{@url}/comments/#{id}", config)
      @comments.remove = (id) => request('DELETE', "#{@url}/comments/#{id}")


  class Event extends Base
    _test: (obj) -> obj.type in ['PushEvent', 'MemberEvent']
    constructor: (request, json) ->
      super

  types = {User, Me, Team, Org, Git, Repo, Gist, Issue, Event}

  module?.exports = types
  return types
