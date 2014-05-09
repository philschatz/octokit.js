# from https://github.com/atom/underscore-plus
camelize = (string) ->
  if string
    string.replace /[_-]+(\w)/g, (m) -> m[1].toUpperCase()
  else
    ''

dasherize = (string) ->
  return '' unless string

  string = string[0].toLowerCase() + string[1..]
  string.replace /([A-Z])|(_)/g, (m, letter) ->
    if letter
      "-#{letter.toLowerCase()}"
    else
      '-'


# Utility classes for various containerish calls:
# like `following`, `members`, `collaborators`, `keys`, `emails`, `git.commits`, `stars`
Createable = (request, root) ->
  fn = () -> request('GET', root)
  fn.create = (config) -> request('POST', root, config)
  fn

CreateRemovable = (request, root) ->
  fn = () -> request('GET', root)
  fn.remove = (id) -> request('DELETE', "#{root}/#{id}")
  fn.create = (config) -> request('POST', root, config)
  fn

Addable = (request, root) ->
  fn = () -> request('GET', root)
  fn.add    = (id) -> request('PUT', "#{root}/#{id}", null, isBoolean:true)
  fn.remove = (id) -> request('DELETE', "#{root}/#{id}", null, isBoolean:true)
  fn

Isable = (request, root) ->
  fn = (id=null) ->
    return request('GET', "#{root}/#{id}", null, isBoolean:true) if id
    return request('GET', root)
  fn.add    = (id) -> request('PUT', "#{root}/#{id}", null, isBoolean:true)
  fn.remove = (id) -> request('DELETE', "#{root}/#{id}", null, isBoolean:true)
  fn

Toggle = (request, root) ->
  fn = () -> request('GET', root, null, isBoolean:true)
  fn.add    = () -> request('PUT', root, null, isBoolean:true)
  fn.remove = () -> request('DELETE', root, null, isBoolean:true)
  fn


# # The Big containers: User, Repo, Gist, Team, Org

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
    @following =
      fetch: () => request('GET', "#{@url}/following")
      'is': (id) => request('GET', "#{@url}/following/#{id}")
    @keys =
      fetch: () => request('GET', "#{@url}/keys")

    @events = (onlyPublic) =>
      pub = ''
      pub = '/public' if onlyPublic is true
      request('GET', "#{@url}/events#{pub}")

    @receivedEvents = (onlyPublic) =>
      pub = ''
      pub = '/public' if onlyPublic is true
      request('GET', "#{@url}/received_events#{pub}")


class Me
  constructor: (request) ->
    @url = '/user'

    @fetch     = () => request('GET', @url)
    @repos     = (config) => request('GET', "#{@url}/repos", config)
    @orgs      = (config) => request('GET', "#{@url}/orgs")
    @gists     = (config) => request('GET', "#{@url}/gists")
    @followers = (config) => request('GET', "#{@url}/followers")
    @following = Isable(request, "#{@url}/following")
    @emails    = Addable(request, "#{@url}/emails")
    @keys      = Addable(request, "#{@url}/keys")
    @key = (id) =>
      fetch: () => request('GET', "#{@url}/keys/#{id}")


class Team extends Base
  _test: (obj) -> /\/teams\//.test(obj.url)
  constructor: (request, json) ->
    super
    @update = (config) => request('PATCH', @url, config)
    # TODO: move remove out of here
    @remove = () => request('DELETE', @url)
    @members = Isable(request, "#{@url}/members")
    @repos =
      fetch:  () => request('GET', "#{@url}/repos")
      add:    (user, name) => request('PUT', "#{@url}/repos/#{user}/#{name}")
      remove: (user, name) => request('DELETE', "#{@url}/repos/#{user}/#{name}")


class Org extends Base
  _test: (obj) -> /\/orgs\//.test(obj.url)
  constructor: (request, json) ->
    super
    @update = (config) => request('PATCH', @url, config)
    @teams = Createable(request, "#{@url}/teams")
    @members = Isable(request, "#{@url}/members")
    @repos =
      fetch:  () => request('GET', "#{@url}/repos")
      create: (name) => request('POST', "#{@url}/repos/#{name}")

class Git
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
  _test: (obj) -> /\/repos\//.test(obj.url)
  constructor: (request, json) ->
    super

    @git = new Git(request, @url)

    @fetch = () => request('GET', @url)
    @update = (config) => request('PATCH', @url, config)
    # TODO: move remove out of here
    @remove = () => request('DELETE', @url)
    @fork = (config) => request('POST', "#{@url}/forks", config)
    @pullRequests =
      create: (config) => request('POST', "#{@url}/pulls", config)
    @events = () => request('GET', "#{@url}/events")
    @issues =
      events: () => request('GET', "#{@url}/issues/events")
    # Network is slightly different because its @url is not `/repos/`
    @network =
      events: () => request('GET', "/networks/#{@owner.login}/#{@name}/events")
    @notifications = (config) => request('GET', "#{@url}/notifications", config)

    @collaborators = Isable(request, "#{@url}/collaborators")

    @hooks = CreateRemovable(request, "#{@url}/hooks")
    @hook = (id) =>
      fetch:  () => request('GET', "#{@url}/hooks/#{id}")
      test:   () => request('POST', "#{@url}/hooks/#{id}/tests")
      update: (config) => request('PATCH', "#{@url}/hooks/#{id}", config)

    @contents = (path, sha) =>
      fetch: () =>
        queryString = toQueryString({ref:sha})
        request('GET', "#{@url}/contents/#{path}#{queryString}", null, {raw:true})
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
    @fetch = () -> request('GET', @url)
    @update = (config) -> request('PATCH', @url, config)
    @remove = () -> request('DELETE', @url)
    @fork = () -> request('POST', "#{@url}/forks")
    @starred = Toggle(request, "#{@url}/star")


TESTABLE_TYPES = [User, Team, Org, Repo, Gist]


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


  # Simple jQuery.ajax() shim that returns a promise for a xhr object
  ajax = (options) ->
    return newPromise (resolve, reject) ->

      xhr = new XMLHttpRequest()
      xhr.dataType = options.dataType
      xhr.overrideMimeType?(options.mimeType)
      xhr.open(options.type, options.url)

      if options.data and 'GET' != options.type
        xhr.setRequestHeader('Content-Type', options.contentType)

      for name, value of options.headers
        xhr.setRequestHeader(name, value)

      xhr.onreadystatechange = () ->
        if 4 == xhr.readyState
          options.statusCode?[xhr.status]?()

          if xhr.status >= 200 and xhr.status < 300 or xhr.status == 304
            resolve(xhr)
          else
            reject(xhr)
      xhr.send(options.data)


  # Returns an always-resolved promise (like `Promise.resolve(val)` )
  resolvedPromise = (val) ->
    return newPromise (resolve, reject) -> resolve(val)

  # Returns an always-rejected promise (like `Promise.reject(err)` )
  rejectedPromise = (err) ->
    return newPromise (resolve, reject) -> reject(err)


  # # Construct the request function.
  # It contains all the auth credentials passed in to the client constructor

  return (clientOptions={}) ->

    # Provide an option to override the default URL
    clientOptions.rootURL ?= 'https://api.github.com'
    clientOptions.useETags ?= true
    clientOptions.usePostInsteadOfPatch ?= false

    # These are updated whenever a request is made
    _listeners = []

    # To support ETag caching cache the responses.
    class ETagResponse
      constructor: (@eTag, @data, @status) ->

    # Cached responses are stored in this object keyed by `path`
    _cachedETags = {}

    # Send simple progress notifications
    notifyStart = (promise, path) -> promise.notify? {type:'start', path:path}
    notifyEnd   = (promise, path) -> promise.notify? {type:'end',   path:path}

    # HTTP Request Abstraction
    # =======
    #
    _request = (method, path, data, options={raw:false, isBase64:false, isBoolean:false}) ->

      if 'PATCH' == method and clientOptions.usePostInsteadOfPatch
        method = 'POST'

      # Only prefix the path when it does not begin with http.
      # This is so pagination works (which provides absolute URLs).
      path = "#{clientOptions.rootURL}#{path}" if not /^http/.test(path)

      # Support binary data by overriding the response mimeType
      mimeType = undefined
      mimeType = 'text/plain; charset=x-user-defined' if options.isBase64

      headers = {
        'Accept': 'application/vnd.github.raw'
      }

      # Set the `User-Agent` because it is required and NodeJS
      # does not send one by default.
      # See http://developer.github.com/v3/#user-agent-required
      headers['User-Agent'] = userAgent if userAgent

      # Send the ETag if re-requesting a URL
      if path of _cachedETags
        headers['If-None-Match'] = _cachedETags[path].eTag
      else
        # The browser will sneak in a 'If-Modified-Since' header if the GET has been requested before
        # but for some reason the cached response does not seem to be available
        # in the jqXHR object.
        # So, the first time a URL is requested set this date to 0 so we always get a response the 1st time
        # a URL is requested.
        headers['If-Modified-Since'] = 'Thu, 01 Jan 1970 00:00:00 GMT'


      if (clientOptions.token) or (clientOptions.username and clientOptions.password)
        if clientOptions.token
          auth = "token #{clientOptions.token}"
        else
          auth = 'Basic ' + base64encode("#{clientOptions.username}:#{clientOptions.password}")
        headers['Authorization'] = auth


      promise = newPromise (resolve, reject) ->

        ajaxConfig =
          # Be sure to **not** blow the cache with a random number
          # (GitHub will respond with 5xx or CORS errors)
          url: path
          type: method
          contentType: 'application/json'
          mimeType: mimeType
          headers: headers

          processData: false # Don't convert to QueryString
          data: !options.raw and data and JSON.stringify(data) or data
          dataType: 'json' unless options.raw

        # If the request is a boolean yes/no question GitHub will indicate
        # via the HTTP Status of 204 (No Content) or 404 instead of a 200.
        if options.isBoolean
          ajaxConfig.statusCode =
            # a Boolean 'yes'
            204: () => resolve(true)
            # a Boolean 'no'
            404: () => resolve(false)

        xhrPromise = ajax(ajaxConfig)

        always = (jqXHR) =>
          notifyEnd(@, path)
          # Fire listeners when the request completes or fails
          rateLimit = parseFloat(jqXHR.getResponseHeader 'X-RateLimit-Limit')
          rateLimitRemaining = parseFloat(jqXHR.getResponseHeader 'X-RateLimit-Remaining')

          for listener in _listeners
            listener(rateLimitRemaining, rateLimit, method, path, data, options)


        # Return the result and Base64 encode it if `options.isBase64` flag is set.
        xhrPromise.then (jqXHR) ->
          always(jqXHR)

          # If the response was a 304 then return the cached version
          if 304 == jqXHR.status
            if clientOptions.useETags and _cachedETags[path]
              eTagResponse = _cachedETags[path]

              resolve(eTagResponse.data, eTagResponse.status, jqXHR)
            else
              resolve(jqXHR.responseText, status, jqXHR)

          # If it was a boolean question and the server responded with 204
          # return true.
          else if 204 == jqXHR.status and options.isBoolean
            resolve(true, status, jqXHR)

          else


            if jqXHR.responseText and 'json' == ajaxConfig.dataType
              data = JSON.parse(jqXHR.responseText)

              # Only JSON responses have next/prev/first/last link headers
              # Add them to data so the resolved value is iterable

              # Parse the Link headers
              # of the form `<http://a.com>; rel="next", <https://b.com?a=b&c=d>; rel="previous"`
              links = jqXHR.getResponseHeader('Link')
              for part in links?.split(',') or []
                [discard, href, rel] = part.match(/<([^>]+)>;\ rel="([^"]+)"/)
                # Add the pagination functions on the JSON since Promises resolve one value
                # Name the functions `nextPage`, `previousPage`, `firstPage`, `lastPage`
                data["#{rel}_page_url"] = href

            else
              data = jqXHR.responseText

            # Convert the response to a Base64 encoded string
            if 'GET' == method and options.isBase64
              # Convert raw data to binary chopping off the higher-order bytes in each char.
              # Useful for Base64 encoding.
              converted = ''
              for i in [0..data.length]
                converted += String.fromCharCode(data.charCodeAt(i) & 0xff)

              data = converted

            # Cache the response to reuse later
            if 'GET' == method and jqXHR.getResponseHeader('ETag') and clientOptions.useETags
              eTag = jqXHR.getResponseHeader('ETag')
              _cachedETags[path] = new ETagResponse(eTag, data, jqXHR.status)

            resolve(data, jqXHR.status, jqXHR)

        # Parse the error if one occurs
        onError = (jqXHR) ->
          always(jqXHR)

          # If the request was for a Boolean then a 404 should be treated as a "false"
          if options.isBoolean and 404 == jqXHR.status
            resolve(false)

          else

            if jqXHR.getResponseHeader('Content-Type') != 'application/json; charset=utf-8'
              reject {error: jqXHR.responseText, status: jqXHR.status, _jqXHR: jqXHR}

            else
              if jqXHR.responseText
                json = JSON.parse(jqXHR.responseText)
              else
                # In the case of 404 errors, `responseText` is an empty string
                json = ''
              reject {error: json, status: jqXHR.status, _jqXHR: jqXHR}

        # Depending on the Promise implementation, the `catch` method may be `.catch` or `.fail`
        xhrPromise.catch?(onError) or xhrPromise.fail(onError)

      notifyStart(promise, path)
      # Return the promise
      return promise


    request = (method, path, data, options={raw:false, isBase64:false, isBoolean:false}) ->


      replacer = (o) ->
        if Array.isArray(o)
          return arrayReplacer(o)
        else if o == Object(o)
          return objReplacer(o)
        else
          return o

      objReplacer = (orig) ->
        acc = {}
        for key, value of orig
          urlReplacer(acc, key, value)

        for Type in TESTABLE_TYPES
          return new Type(request, acc) if Type::_test(acc)
        acc

      arrayReplacer = (orig) ->
        arr = (replacer(item) for item in orig)

      # Convert things that end in `_url` to methods which return a Promise
      urlReplacer = (acc, key, value) ->
        if /_url$/.test(key)
          fn = () ->
            # url can contain {name} or {/name} in the URL.
            # for every arg passed in, replace {...} with that arg
            # and remove the rest (they may or may not be optional)
            i = 0
            while m = /(\{[^\}]+\})/.exec(value)
              # `match` is something like `{/foo}`
              match = m[1]
              if i++ < arguments.length
                # replace it
                param = arguments[i]
                param = "/#{param}" if match[1] = '/'
              else
                # Discard the remaining optional params in the URL
                param = ''
              value = value.replace(match, param)

            request('GET', value, null) # TODO: Heuristically set the isBoolean flag
          fn.url = value
          newKey = key.substring(0, key.length-'_url'.length)
          acc[camelize(newKey)] = fn

        else
          acc[camelize(key)] = replacer(value)


      return _request(arguments...)
      .then (val) ->
        return replacer(val) unless options.raw
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


module.exports = Octokit
