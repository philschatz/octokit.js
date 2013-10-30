# Github Promise API
# ======
#
# This class provides a Promise API for accessing GitHub
# (see [jQuery.Deferred](http://api.jquery.com/jQuery.deferred)).
# Most methods return a Promise object whose value is resolved when `.then(doneFn, failFn)`
# is called.
#

# Based on Github.js 0.7.0
#
#     (c) 2012 Michael Aufreiter, Development Seed
#     Github.js is freely distributable under the MIT license.
#     For all details and documentation:
#     http://substance.io/michael/github

# Generate a Github class
# =========
#
# Depending on how this is loaded (nodejs, requirejs, globals)
# the actual underscore, jQuery.ajax/Deferred, and base64 encode functions may differ.
makeOctokit = (_, jQuery, base64encode, userAgent) =>


  # Modify methods that return a Promise to accept an optional callback
  # as the last argument to the function
  cbWrap = (func) ->
    return () ->
      # Split off the last argument if it is a function
      last = _.last(arguments)
      if _.isFunction(last)
        promise = func.apply(@, _.initial arguments)
        promise.done (val) -> last(null, val)
        promise.fail (err) -> last(err or true) # in case the error returned is null
        return promise
      else
        return func.apply(@, arguments)


  class Octokit

    constructor: (clientOptions={}) ->
      # Provide an option to override the default URL
      _.defaults clientOptions,
        rootURL: 'https://api.github.com'
        useETags: true

      _client = @ # Useful for other classes (like Repo) to get the current Client object

      # These are updated whenever a request is made
      _listeners = []

      # To support ETag caching cache the responses.
      class ETagResponse
        constructor: (@eTag, @data, @textStatus, @jqXHR) ->

      # Cached responses are stored in this object keyed by `path`
      _cachedETags = {}

      # Send simple progress notifications
      notifyStart = (promise, path) -> promise.notify {type:'start', path:path}
      notifyEnd   = (promise, path) -> promise.notify {type:'end',   path:path}

      # HTTP Request Abstraction
      # =======
      #
      _request = (method, path, data, options={raw:false, isBase64:false, isBoolean:false}) ->

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


        promise = new jQuery.Deferred()

        ajaxConfig =
          # Be sure to **not** blow the cache with a random number
          # (GitHub will respond with 5xx or CORS errors)
          url: clientOptions.rootURL + path
          type: method
          contentType: 'application/json'
          mimeType: mimeType
          headers: headers

          processData: false # Don't convert to QueryString
          data: !options.raw and data and JSON.stringify(data) or data
          dataType: 'json' unless options.raw

        # If the request is a boolean yes/no question GitHub will indicate
        # via the HTTP Status of 204 (No Content) or 404 instead of a 200.
        # Also, jQuery will never call `xhr.resolve` so we need to use a
        # different promise later on.
        if options.isBoolean
          ajaxConfig.statusCode =
            # a Boolean 'yes'
            204: () => notifyEnd(promise, path); promise.resolve(true)
            # a Boolean 'no'
            404: () => notifyEnd(promise, path); promise.resolve(false)

        jqXHR = jQuery.ajax(ajaxConfig)

        jqXHR.always =>
          notifyEnd(promise, path)
          # Fire listeners when the request completes or fails
          rateLimit = parseFloat(jqXHR.getResponseHeader 'X-RateLimit-Limit')
          rateLimitRemaining = parseFloat(jqXHR.getResponseHeader 'X-RateLimit-Remaining')

          for listener in _listeners
            listener(rateLimitRemaining, rateLimit, method, path, data, options)


        # Return the result and Base64 encode it if `options.isBase64` flag is set.
        jqXHR.done (data, textStatus) ->
          # If the response was a 304 then return the cached version
          if 304 == jqXHR.status
            if clientOptions.useETags and _cachedETags[path]
              eTagResponse = _cachedETags[path]

              promise.resolve(eTagResponse.data, eTagResponse.textStatus, eTagResponse.jqXHR)
            else
              promise.resolve(jqXHR.responseText, textStatus, jqXHR)

          # If it was a boolean question and the server responded with 204
          # return true.
          else if 204 == jqXHR.status and options.isBoolean
            promise.resolve(true, textStatus, jqXHR)

          else

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
              _cachedETags[path] = new ETagResponse(eTag, data, textStatus, jqXHR)

            promise.resolve(data, textStatus, jqXHR)

        # Parse the error if one occurs
        .fail (unused, msg, desc) ->
          # If the request was for a Boolean then a 404 should be treated as a "false"
          if options.isBoolean and 404 == jqXHR.status
            promise.resolve(false)

          else

            if jqXHR.getResponseHeader('Content-Type') != 'application/json; charset=utf-8'
              promise.reject {error: jqXHR.responseText, status: jqXHR.status, _jqXHR: jqXHR}

            else
              if jqXHR.responseText
                json = JSON.parse jqXHR.responseText
              else
                # In the case of 404 errors, `responseText` is an empty string
                json = ''
              promise.reject {error: json, status: jqXHR.status, _jqXHR: jqXHR}

        notifyStart(promise, path)
        # Return the promise
        return promise.promise()


      # Converts a dictionary to a query string.
      # Internal helper method
      toQueryString = (options) ->

        # Returns '' if `options` is empty so this string can always be appended to a URL
        return '' if _.isEmpty(options)

        params = []
        _.each _.pairs(options), ([key, value]) ->
          params.push "#{key}=#{encodeURIComponent(value)}"
        return "?#{params.join('&')}"

      # Clear the local cache
      # -------
      @clearCache = clearCache = () -> _cachedETags = {}

      # Add a listener that fires when the `rateLimitRemaining` changes as a result of
      # communicating with github.
      @onRateLimitChanged = (listener) ->
        _listeners.push listener

      # Random zen quote (test the API)
      # -------
      @getZen = cbWrap () ->
        # Send `data` to `null` and the `raw` flag to `true`
        _request 'GET', '/zen', null, {raw:true}

      # Get all users
      # -------
      @getAllUsers = cbWrap (since=null) ->
        options = {}
        options.since = since if since
        _request 'GET', '/users', options

      # List public repositories for an Organization
      # -------
      @getOrgRepos = cbWrap (orgName, type='all') ->
        _request 'GET', "/orgs/#{orgName}/repos?type=#{type}&per_page=1000&sort=updated&direction=desc", null

      # Get public Gists on all of GitHub
      # -------
      @getPublicGists = cbWrap (since=null) ->
        options = null
        # Converts a Date object to a string
        getDate = (time) ->
          return time.toISOString() if Date == time.constructor
          return time

        options = {since: getDate(since)} if since
        _request 'GET', '/gists/public', options

      # List Public Events on all of GitHub
      # -------
      @getPublicEvents = cbWrap () ->
        _request 'GET', '/events', null


      # List unread notifications for authenticated user
      # -------
      # Optional arguments:
      #
      # - `all`: `true` to show notifications marked as read.
      # - `participating`: `true` to show only notifications in which the user is directly participating or mentioned.
      # - `since`: Optional time.
      @getNotifications = cbWrap (options={}) ->
        # Converts a Date object to a string
        getDate = (time) ->
          return time.toISOString() if Date == time.constructor
          return time

        options.since = getDate(options.since) if options.since

        queryString = toQueryString(options)
        _request 'GET', "/notifications#{queryString}", null


      # Github Users API
      # =======
      class User

        # Store the username
        constructor: (_username=null) ->

          # Private var that stores the root path.
          # Use a different URL if this user is the authenticated user
          if _username
            _rootPath = "/users/#{_username}"
          else
            _rootPath = "/user"

          # Retrieve user information
          # -------
          _cachedInfo = null
          @getInfo = cbWrap (force=false) ->
            _cachedInfo = null if force

            if _cachedInfo
              promise = new jQuery.Deferred()
              promise.resolve(_cachedInfo)
              return promise

            _request('GET', "#{_rootPath}", null)
            # Squirrel away the user info
            .done (info) -> _cachedInfo = info

          # List user repositories
          # -------
          @getRepos = cbWrap () ->
            _request 'GET', "#{_rootPath}/repos?type=all&per_page=1000&sort=updated", null

          # List user organizations
          # -------
          @getOrgs = cbWrap () ->
            _request 'GET', "#{_rootPath}/orgs", null

          # List a user's gists
          # -------
          @getGists = cbWrap () ->
            _request 'GET', "#{_rootPath}/gists", null

          # List followers of a user
          # -------
          @getFollowers = cbWrap () ->
            _request 'GET', "#{_rootPath}/followers", null

          # List who this user is following
          # -------
          @getFollowing = cbWrap () ->
            _request 'GET', "#{_rootPath}/following", null

          # Check if this user is following another user
          # -------
          @isFollowing = cbWrap (user) ->
            _request 'GET', "#{_rootPath}/following/#{user}", null, {isBoolean:true}

          # List public keys for a user
          # -------
          @getPublicKeys = cbWrap () ->
            _request 'GET', "#{_rootPath}/keys", null


          # Get Received events for this user
          # -------
          @getReceivedEvents = cbWrap (onlyPublic) ->
            throw new Error 'BUG: This does not work for authenticated users yet!' if not _username
            isPublic = ''
            isPublic = '/public' if onlyPublic
            _request 'GET', "/users/#{_username}/received_events#{isPublic}", null

          # Get all events for this user
          # -------
          @getEvents = cbWrap (onlyPublic) ->
            throw new Error 'BUG: This does not work for authenticated users yet!' if not _username
            isPublic = ''
            isPublic = '/public' if onlyPublic
            _request 'GET', "/users/#{_username}/events#{isPublic}", null


      # Authenticated User API
      # =======
      class AuthenticatedUser extends User

        constructor: () ->
          super()

          # Update the authenticated user
          # -------
          #
          # Valid options:
          # - `name`: String
          # - `email` : Publicly visible email address
          # - `blog`: String
          # - `company`: String
          # - `location`: String
          # - `hireable`: Boolean
          # - `bio`: String
          @updateInfo = cbWrap (options) ->
            _request 'PATCH', '/user', options

          # List authenticated user's gists
          # -------
          @getGists = cbWrap () ->
            _request 'GET', '/gists', null

          # Follow a user
          # -------
          @follow = cbWrap (username) ->
            _request 'PUT', "/user/following/#{username}", null

          # Unfollow user
          # -------
          @unfollow = cbWrap (username) ->
            _request 'DELETE', "/user/following/#{username}", null

          # Get Emails associated with this user
          # -------
          @getEmails = cbWrap () ->
            _request 'GET', '/user/emails', null

          # Add Emails associated with this user
          # -------
          @addEmail = cbWrap (emails) ->
            emails = [emails] if !_.isArray(emails)
            _request 'POST', '/user/emails', emails

          # Remove Emails associated with this user
          # -------
          @addEmail = cbWrap (emails) ->
            emails = [emails] if !_.isArray(emails)
            _request 'DELETE', '/user/emails', emails

          # Get a single public key
          # -------
          @getPublicKey = cbWrap (id) ->
            _request 'GET', "/user/keys/#{id}", null

          # Add a public key
          # -------
          @addPublicKey = cbWrap (title, key) ->
            _request 'POST', "/user/keys", {title: title, key: key}

          # Update a public key
          # -------
          @updatePublicKey = cbWrap (id, options) ->
            _request 'PATCH', "/user/keys/#{id}", options

          # Create a repository
          # -------
          #
          # Optional parameters:
          # - `description`: String
          # - `homepage`: String
          # - `private`: boolean (Default `false`)
          # - `has_issues`: boolean (Default `true`)
          # - `has_wiki`: boolean (Default `true`)
          # - `has_downloads`: boolean (Default `true`)
          # - `auto_init`:  boolean (Default `false`)
          @createRepo = cbWrap (name, options={}) ->
            options.name = name
            _request 'POST', "/user/repos", options



      # Organization API
      # =======

      class Team
        constructor: (@id) ->
          @getInfo = cbWrap () ->
            _request 'GET', "/teams/#{@id}", null

          # - `name`
          # - `permission`
          @updateTeam = cbWrap (options) ->
            _request 'PATCH', "/teams/#{@id}", options

          @remove = cbWrap () ->
            _request 'DELETE', "/teams/#{@id}"

          @getMembers = cbWrap () ->
            _request 'GET', "/teams/#{@id}/members"

          @isMember = cbWrap (user) ->
            _request 'GET', "/teams/#{@id}/members/#{user}", null, {isBoolean:true}

          @addMember = cbWrap (user) ->
            _request 'PUT', "/teams/#{@id}/members/#{user}"

          @removeMember = cbWrap (user) ->
            _request 'DELETE', "/teams/#{@id}/members/#{user}"

          @getRepos = cbWrap () ->
            _request 'GET', "/teams/#{@id}/repos"

          @addRepo = cbWrap (orgName, repoName) ->
            _request 'PUT', "/teams/#{@id}/repos/#{orgName}/#{repoName}"

          @removeRepo = cbWrap (orgName, repoName) ->
            _request 'DELETE', "/teams/#{@id}/repos/#{orgName}/#{repoName}"


      class Organization
        constructor: (@name) ->

          @getInfo = cbWrap () ->
            _request 'GET', "/orgs/#{@name}", null

          # - `billing_email`: Billing email address. This address is not publicized.
          # - `company`
          # - `email`
          # - `location`
          # - `name`
          @updateInfo = cbWrap (options) ->
            _request 'PATCH', "/orgs/#{@name}", options

          @getTeams = cbWrap () ->
            _request 'GET', "/orgs/#{@name}/teams", null

          # `permission` can be one of `pull`, `push`, or `admin`
          @createTeam = cbWrap (name, repoNames=null, permission='pull') ->
            options = {name: name, permission: permission}
            options.repo_names = repoNames if repoNames
            _request 'POST', "/orgs/#{@name}/teams", options

          @getMembers = cbWrap () ->
            _request 'GET', "/orgs/#{@name}/members", null

          @isMember = cbWrap (user) ->
            _request 'GET', "/orgs/#{@name}/members/#{user}", null, {isBoolean:true}

          @removeMember = cbWrap (user) ->
            _request 'DELETE', "/orgs/#{@name}/members/#{user}", null

          # Create a repository
          # -------
          #
          # Optional parameters are the same as `.getUser().createRepo()` with one addition:
          # - `team_id`:  number
          @createRepo = cbWrap (name, options={}) ->
            options.name = name
            _request 'POST', "/orgs/#{@name}/repos", options


      # Repository API
      # =======

      # Low-level class for manipulating a Git Repository
      # -------
      class GitRepo

        constructor: (@repoUser, @repoName) ->
          _repoPath = "/repos/#{@repoUser}/#{@repoName}"

          # Delete this Repository
          # -------
          # **Note:** This is here instead of on the `Repository` object
          # so it is less likely to accidentally be used.
          @deleteRepo = cbWrap () ->
            _request 'DELETE', "#{_repoPath}"

          # Uses the cache if branch has not been changed
          # -------
          @_updateTree = (branch) ->
            @getRef("heads/#{branch}")
            # Return the promise
            .promise()


          # Get a particular reference
          # -------
          @getRef = cbWrap (ref) ->
            _request('GET', "#{_repoPath}/git/refs/#{ref}", null)
            .then (res) =>
              return res.object.sha
            # Return the promise
            .promise()


          # Create a new reference
          # --------
          #
          #     {
          #       "ref": "refs/heads/my-new-branch-name",
          #       "sha": "827efc6d56897b048c772eb4087f854f46256132"
          #     }
          @createRef = cbWrap (options) ->
            _request 'POST', "#{_repoPath}/git/refs", options


          # Delete a reference
          # --------
          #
          #     repo.deleteRef('heads/gh-pages')
          #     repo.deleteRef('tags/v1.0')
          @deleteRef = cbWrap (ref) ->
            _request 'DELETE', "#{_repoPath}/git/refs/#{ref}", @options


          # List all branches of a repository
          # -------
          @getBranches = cbWrap () ->
            _request('GET', "#{_repoPath}/git/refs/heads", null)
            .then (heads) =>
              return _.map(heads, (head) ->
                _.last head.ref.split("/")
              )
            # Return the promise
            .promise()


          # Retrieve the contents of a blob
          # -------
          @getBlob = cbWrap (sha, isBase64) ->
            _request 'GET', "#{_repoPath}/git/blobs/#{sha}", null, {raw:true, isBase64:isBase64}


          # For a given file path, get the corresponding sha (blob for files, tree for dirs)
          # -------
          @getSha = cbWrap (branch, path) ->
            # Just use head if path is empty
            return @getRef("heads/#{branch}") if path is ''

            @getTree(branch, {recursive:true})
            .then (tree) =>
              file = _.select(tree, (file) ->
                file.path is path
              )[0]
              return file?.sha if file?.sha

              # Return a promise that has failed if no sha was found
              return (new jQuery.Deferred()).reject {message: 'SHA_NOT_FOUND'}

            # Return the promise
            .promise()


          # Get contents (file/dir)
          # -------
          @getContents = cbWrap (path, sha=null) ->
            queryString = ''
            if sha != null
              queryString = toQueryString({ref:sha})
            _request('GET', "#{_repoPath}/contents/#{path}#{queryString}", null, {raw:true})
            .then (contents) =>
              return contents
            # Return the promise
            .promise()


          # Retrieve the tree a commit points to
          # -------
          # Optionally set recursive to true
          @getTree = cbWrap (tree, options=null) ->
            queryString = toQueryString(options)
            _request('GET', "#{_repoPath}/git/trees/#{tree}#{queryString}", null)
            .then (res) =>
              return res.tree
            # Return the promise
            .promise()


          # Post a new blob object, getting a blob SHA back
          # -------
          @postBlob = cbWrap (content, isBase64) ->
            if typeof (content) is 'string'
              # Base64 encode the content if it is binary (isBase64)
              content = base64encode(content) if isBase64

              content =
                content: content
                encoding: 'utf-8'

            content.encoding = 'base64' if isBase64

            _request('POST', "#{_repoPath}/git/blobs", content)
            .then (res) =>
              return res.sha
            # Return the promise
            .promise()


          # Update an existing tree adding a new blob object getting a tree SHA back
          # -------
          # `newTree` is of the form:
          #
          #     [ {
          #       path: path
          #       mode: '100644'
          #       type: 'blob'
          #       sha: blob
          #     } ]
          @updateTreeMany = cbWrap (baseTree, newTree) ->
            data =
              base_tree: baseTree
              tree: newTree

            _request('POST', "#{_repoPath}/git/trees", data)
            .then (res) =>
              return res.sha
            # Return the promise
            .promise()


          # Post a new tree object having a file path pointer replaced
          # with a new blob SHA getting a tree SHA back
          # -------
          @postTree = cbWrap (tree) ->
            _request('POST', "#{_repoPath}/git/trees", {tree: tree})
            .then (res) =>
              return res.sha
            # Return the promise
            .promise()


          # Create a new commit object with the current commit SHA as the parent
          # and the new tree SHA, getting a commit SHA back
          # -------
          @commit = cbWrap (parents, tree, message) ->
            parents = [parents] if not _.isArray(parents)
            data =
              message: message
              parents: parents
              tree: tree

            _request('POST', "#{_repoPath}/git/commits", data)
            .then((commit) -> return commit.sha)
            # Return the promise
            .promise()


          # Update the reference of your head to point to the new commit SHA
          # -------
          @updateHead = cbWrap (head, commit) ->
            _request 'PATCH', "#{_repoPath}/git/refs/heads/#{head}", {sha: commit}


          # Get a single commit
          # --------------------
          @getCommit = cbWrap (sha) ->
            _request('GET', "#{_repoPath}/commits/#{sha}", null)

          # List commits on a repository.
          # -------
          # Takes an object of optional paramaters:
          #
          # - `sha`: SHA or branch to start listing commits from
          # - `path`: Only commits containing this file path will be returned
          # - `author`: GitHub login, name, or email by which to filter by commit author
          # - `since`: ISO 8601 date - only commits after this date will be returned
          # - `until`: ISO 8601 date - only commits before this date will be returned
          @getCommits = cbWrap (options={}) ->
            options = _.extend {}, options

            # Converts a Date object to a string
            getDate = (time) ->
              return time.toISOString() if Date == time.constructor
              return time

            options.since = getDate(options.since) if options.since
            options.until = getDate(options.until) if options.until

            queryString = toQueryString(options)

            _request('GET', "#{_repoPath}/commits#{queryString}", null)
            # Return the promise
            .promise()


      # Branch Class
      # -------
      # Provides common methods that may require several git operations.
      class Branch

        constructor: (git, getRef) ->
          # Private variables
          _git = git
          _getRef = getRef or -> throw new Error 'BUG: No way to fetch branch ref!'

          # Get a single commit
          # --------------------
          @getCommit = cbWrap (sha) -> _git.getCommit(sha)

          # List commits on a branch.
          # -------
          # Takes an object of optional paramaters:
          #
          # - `path`: Only commits containing this file path will be returned
          # - `author`: GitHub login, name, or email by which to filter by commit author
          # - `since`: ISO 8601 date - only commits after this date will be returned
          # - `until`: ISO 8601 date - only commits before this date will be returned
          @getCommits = cbWrap (options={}) ->
            options = _.extend {}, options
            # Limit to the current branch
            _getRef()
            .then (branch) ->
              options.sha = branch
              _git.getCommits(options)

            # Return the promise
            .promise()


          # Creates a new branch based on the current reference of this branch
          # -------
          @createBranch = cbWrap (newBranchName) ->
            _getRef()
            .then (branch) =>
              _git.getSha(branch, '')
              .then (sha) =>
                _git.createRef({sha:sha, ref:"refs/heads/#{newBranchName}"})

            # Return the promise
            .promise()


          # Read file at given path
          # -------
          # Set `isBase64=true` to get back a base64 encoded binary file
          @read = cbWrap (path, isBase64) ->
            _getRef()
            .then (branch) =>
              _git.getSha(branch, path)
              .then (sha) =>
                _git.getBlob(sha, isBase64)
                # Return both the commit hash and the content
                .then (bytes) =>
                  return {sha:sha, content:bytes}
            # Return the promise
            .promise()


          # Get contents at given path
          # -------
          @contents = cbWrap (path) ->
            _getRef()
            .then (branch) =>
              _git.getSha(branch, '')
              .then (sha) =>
                _git.getContents(path, sha)
                .then (contents) =>
                  return contents
            # Return the promise
            .promise()


          # Remove a file from the tree
          # -------
          @remove = cbWrap (path, message="Removed #{path}") ->
            _getRef()
            .then (branch) =>
              _git._updateTree(branch)
              .then (latestCommit) =>
                _git.getTree(latestCommit, {recursive:true})
                .then (tree) =>
                  newTree = _.reject(tree, (ref) -> # Update Tree
                    ref.path is path
                  )
                  _.each newTree, (ref) ->
                    delete ref.sha  if ref.type is 'tree'

                  _git.postTree(newTree)
                  .then (rootTree) =>
                    _git.commit(latestCommit, rootTree, message)
                    .then (commit) =>
                      _git.updateHead(branch, commit)
                      .then (res) =>
                        return res # Finally, return the result

            # Return the promise
            .promise()


          # Move a file to a new location
          # -------
          @move = cbWrap (path, newPath, message="Moved #{path}") ->
            _getRef()
            .then (branch) =>
              _git._updateTree(branch)
              .then (latestCommit) =>
                _git.getTree(latestCommit, {recursive:true})
                .then (tree) => # Update Tree
                  _.each tree, (ref) ->
                    ref.path = newPath  if ref.path is path
                    delete ref.sha  if ref.type is 'tree'

                  _git.postTree(tree)
                  .then (rootTree) =>
                    _git.commit(latestCommit, rootTree, message)
                    .then (commit) =>
                      _git.updateHead(branch, commit)
                      .then (res) =>
                        return res # Finally, return the result
            # Return the promise
            .promise()


          # Write file contents to a given branch and path
          # -------
          # To write base64 encoded data set `isBase64==true`
          #
          # Optionally takes a `parentCommitSha` which will be used as the
          # parent of this commit
          @write = cbWrap (path, content, message="Changed #{path}", isBase64, parentCommitSha=null) ->
            contents = {}
            contents[path] =
              content: content
              isBase64: isBase64

            @writeMany(contents, message, parentCommitSha)
            # Return the promise
            .promise()


          # Write the contents of multiple files to a given branch
          # -------
          # Each file can also be binary.
          #
          # In general `contents` is a map where the key is the path and the value is `{content:'Hello World!', isBase64:false}`.
          # In the case of non-base64 encoded files the value may be a string instead.
          #
          # Example:
          #
          #     contents = {
          #       'hello.txt':          'Hello World!',
          #       'path/to/hello2.txt': { content: 'Ahoy!', isBase64: false}
          #     }
          #
          # Optionally takes an array of `parentCommitShas` which will be used as the
          # parents of this commit.
          @writeMany = cbWrap (contents, message="Changed Multiple", parentCommitShas=null) ->
            # This method:
            #
            # 0. Finds the latest commit if one is not provided
            # 1. Asynchronously send new blobs for each file
            # 2. Use the return of the new Blob Post to return an entry in the new Commit Tree
            # 3. Wait on all the new blobs to finish
            # 4. Commit and update the branch
            _getRef()
            .then (branch) => # See below for Step 0.
              afterParentCommitShas = (parentCommitShas) => # 1. Asynchronously send all the files as new blobs.
                promises = _.map _.pairs(contents), ([path, data]) ->
                  # `data` can be an object or a string.
                  # If it is a string assume isBase64 is false and the string is the content
                  content = data.content or data
                  isBase64 = data.isBase64 or false
                  _git.postBlob(content, isBase64)
                  .then (blob) => # 2. return an entry in the new Commit Tree
                    return {
                      path: path
                      mode: '100644'
                      type: 'blob'
                      sha: blob
                    }
                # 3. Wait on all the new blobs to finish
                $.when.apply($, promises)
                .then (newTree1, newTree2, newTreeN) =>
                  newTrees = _.toArray(arguments) # Convert args from $.when back to an array. kludgy
                  _git.updateTreeMany(parentCommitShas, newTrees)
                  .then (tree) => # 4. Commit and update the branch
                    _git.commit(parentCommitShas, tree, message)
                    .then (commitSha) =>
                      _git.updateHead(branch, commitSha)
                      .then (res) => # Finally, return the result
                        return res.object # Return something that has a `.sha` to match the signature for read

              # 0. Finds the latest commit if one is not provided
              if parentCommitShas
                return afterParentCommitShas(parentCommitShas)
              else
                return _git._updateTree(branch).then(afterParentCommitShas)

            # Return the promise
            .promise()


      # Repository Class
      # -------
      # Provides methods for operating on the entire repository
      # and ways to operate on a `Branch`.
      class Repository

        constructor: (@options) ->
          # Private fields
          _user = @options.user
          _repo = @options.name

          # Set the `git` instance variable
          @git = new GitRepo(_user, _repo)
          @repoPath = "/repos/#{_user}/#{_repo}"

          # List all branches of a repository
          # -------
          @getBranches = () -> @git.getBranches()


          # Get a branch of a repository
          # -------
          @getBranch = (branchName) ->
            getRef = =>
              deferred = new jQuery.Deferred()
              deferred.resolve(branchName)
              deferred
            new Branch(@git, getRef)


          # Get the default branch of a repository
          # -------
          @getDefaultBranch = () ->
            # Calls getInfo() to get the default branch name
            getRef = =>
              @getInfo()
              .then (info) =>
                return info.master_branch
            new Branch(@git, getRef)


          # Get repository information
          # -------
          @getInfo = cbWrap () ->
            _request 'GET', @repoPath, null

          # Get contents
          # --------
          @getContents = cbWrap (branch, path) ->
            _request 'GET', "#{@repoPath}/contents?ref=#{branch}", {path: path}


          # Fork repository
          # -------
          @fork = cbWrap () ->
            _request 'POST', "#{@repoPath}/forks", null


          # Create pull request
          # --------
          @createPullRequest = cbWrap (options) ->
            _request 'POST', "#{@repoPath}/pulls", options


          # Get recent commits to the repository
          # --------
          # Takes an object of optional paramaters:
          #
          # - `path`: Only commits containing this file path will be returned
          # - `author`: GitHub login, name, or email by which to filter by commit author
          # - `since`: ISO 8601 date - only commits after this date will be returned
          # - `until`: ISO 8601 date - only commits before this date will be returned
          @getCommits = cbWrap (options) ->
            @git.getCommits(options)


          # List repository events
          # -------
          @getEvents = cbWrap () ->
            _request 'GET', "#{@repoPath}/events", null

          # List Issue events for a Repository
          # -------
          @getIssueEvents = cbWrap () ->
            _request 'GET', "#{@repoPath}/issues/events", null

          # List events for a network of Repositories
          # -------
          @getNetworkEvents = cbWrap () ->
            _request 'GET', "/networks/#{_owner}/#{_repo}/events", null


          # List unread notifications for authenticated user
          # -------
          # Optional arguments:
          #
          # - `all`: `true` to show notifications marked as read.
          # - `participating`: `true` to show only notifications in which
          #   the user is directly participating or mentioned.
          # - `since`: Optional time.
          @getNotifications = cbWrap (options={}) ->
            # Converts a Date object to a string
            getDate = (time) ->
              return time.toISOString() if Date == time.constructor
              return time

            options.since = getDate(options.since) if options.since

            queryString = toQueryString(options)

            _request 'GET', "#{@repoPath}/notifications#{queryString}", null

          # List Collaborators
          # -------
          # When authenticating as an organization owner of an
          # organization-owned repository, all organization owners
          # are included in the list of collaborators.
          # Otherwise, only users with access to the repository are
          # returned in the collaborators list.
          @getCollaborators = cbWrap () ->
            _request 'GET', "#{@repoPath}/collaborators", null

          @isCollaborator = cbWrap (username=null) ->
            throw new Error 'BUG: username is required' if not username
            _request 'GET', "#{@repoPath}/collaborators/#{username}", null, {isBoolean:true}

          # Can Collaborate
          # -------
          # True if the authenticated user has permission
          # to commit to this repository.
          @canCollaborate = cbWrap () ->
            # Short-circuit if no credentials provided
            if not (clientOptions.password or clientOptions.token)
              return (new $.Deferred()).resolve(false)

            _client.getLogin()
            .then (login) =>
              if not login
                return false
              else
                return @isCollaborator(login)
            .then null, (err) =>
              # Problem logging in (maybe bad username/password)
              return false


          # List all hooks
          # -------
          @getHooks = cbWrap () ->
            _request 'GET', "#{@repoPath}/hooks", null

          # Get single hook
          # -------
          @getHook = cbWrap (id) ->
            _request 'GET', "#{@repoPath}/hooks/#{id}", null

          # Create a new hook
          # -------
          #
          # - `name` (Required string) : The name of the service that is being called.
          #         (See /hooks for the list of valid hook names.)
          # - `config` (Required hash) : A Hash containing key/value pairs to provide settings for this hook.
          #                              These settings vary between the services and are defined in the github-services repo.
          # - `events` (Optional array) : Determines what events the hook is triggered for. Default: ["push"].
          # - `active` (Optional boolean) : Determines whether the hook is actually triggered on pushes.
          @createHook = cbWrap (name, config, events=['push'], active=true) ->
            data =
              name: name
              config: config
              events: events
              active: active

            _request 'POST', "#{@repoPath}/hooks", data

          # Edit a hook
          # -------
          #
          # - `config` (Optional hash) : A Hash containing key/value pairs to provide settings for this hook.
          #                      Modifying this will replace the entire config object.
          #                      These settings vary between the services and are defined in the github-services repo.
          # - `events` (Optional array) : Determines what events the hook is triggered for.
          #                     This replaces the entire array of events. Default: ["push"].
          # - `addEvents` (Optional array) : Determines a list of events to be added to the list of events that the Hook triggers for.
          # - `removeEvents` (Optional array) : Determines a list of events to be removed from the list of events that the Hook triggers for.
          # - `active` (Optional boolean) : Determines whether the hook is actually triggered on pushes.
          @editHook = cbWrap (id, config=null, events=null, addEvents=null, removeEvents=null, active=null) ->
            data = {}
            data.config = config if config != null
            data.events = events if events != null
            data.add_events = addEvents if addEvents != null
            data.remove_events = removeEvents if removeEvents != null
            data.active = active if active != null

            _request 'PATCH', "#{@repoPath}/hooks/#{id}", data

          # Test a `push` hook
          # -------
          # This will trigger the hook with the latest push to the current
          # repository if the hook is subscribed to push events.
          # If the hook is not subscribed to push events, the server will
          # respond with 204 but no test POST will be generated.
          @testHook = cbWrap (id) ->
            _request 'POST', "#{@repoPath}/hooks/#{id}/tests", null

          # Delete a hook
          # -------
          @deleteHook = cbWrap (id) ->
            _request 'DELETE', "#{@repoPath}/hooks/#{id}", null

          # List all Languages
          # -------
          @getLanguages = cbWrap () ->
            _request 'GET', "#{@repoPath}/languages", null


      # Gist API
      # -------
      class Gist
        constructor: (@options) ->
          id = @options.id
          _gistPath = "/gists/#{id}"


          # Read the gist
          # --------
          @read = cbWrap () ->
            _request 'GET', _gistPath, null


          # Create the gist
          # --------
          #
          # Files contains a hash with the filename as the key and
          # `{content: 'File Contents Here'}` as the value.
          #
          # Example:
          #
          #     { "file1.txt": {
          #         "content": "String file contents"
          #       }
          #     }
          @create = cbWrap (files, isPublic=false, description=null) ->
            options =
              isPublic: isPublic
              files: files
            options.description = description if description?
            _request 'POST', "/gists", options


          # Delete the gist
          # --------
          @delete = cbWrap () ->
            _request 'DELETE', _gistPath, null


          # Fork a gist
          # --------
          @fork = cbWrap () ->
            _request 'POST', "#{_gistPath}/forks", null


          # Update a gist with the new stuff
          # --------
          # `files` are files that make up this gist.
          # The key of which should be an optional string filename
          # and the value another optional hash with parameters:
          #
          # - `content`: Optional string - Updated file contents
          # - `filename`: Optional string - New name for this file.
          #
          # **NOTE:** All files from the previous version of the gist are carried
          # over by default if not included in the hash. Deletes can be performed
          # by including the filename with a null hash.
          @update = cbWrap (files, description=null) ->
            options = {files: files}
            options.description = description if description?
            _request 'PATCH', _gistPath, options

          # Star a gist
          # -------
          @star = cbWrap () ->
            _request 'PUT', "#{_gistPath}/star"

          # Unstar a gist
          # -------
          @unstar = cbWrap () ->
            _request 'DELETE', "#{_gistPath}/star"

          # Check if a gist is starred
          # -------
          @isStarred = cbWrap () ->
            _request 'GET', "#{_gistPath}", null, {isBoolean:true}



      # Top Level API
      # -------
      @getRepo = (user, repo) ->
        throw new Error('BUG! user argument is required') if not user
        throw new Error('BUG! repo argument is required') if not repo

        new Repository(
          user: user
          name: repo
        )

      # API for viewing info for arbitrary users or the current user
      # if no arguments are provided.
      @getUser = (login=null) ->
        if login
          return new User(login)
        else if clientOptions.password or clientOptions.token
          return new AuthenticatedUser()
        else
          return null

      @getGist = (id) ->
        new Gist(id: id)

      # Returns the login of the current user.
      # When using OAuth this is unknown but is necessary to
      # determine if the current user has commit access to a
      # repository
      @getLogin = cbWrap () ->
        # 3 cases:
        # 1. No authentication provided
        # 2. Username (and password) provided
        # 3. OAuth token provided
        if clientOptions.password or clientOptions.token
          return new User().getInfo()
          .then (info) ->
            return info.login
        else
          ret = new jQuery.Deferred()
          ret.resolve(null)
          return ret


  # Return the class for assignment
  return Octokit

# Register with nodejs, requirejs, or as a global
# -------
# Depending on the context this file is called, register it appropriately

# If using this as a nodejs module use `jquery-deferred` and `najax` to make a jQuery object
if exports?
  _ = require 'underscore'
  jQuery = require 'jquery-deferred'
  najax = require 'najax'
  jQuery.ajax = najax
  # Encode using native Base64
  encode = (str) ->
    buffer = new Buffer str, 'binary'
    buffer.toString 'base64'
  Octokit = makeOctokit _, jQuery, encode, 'octokit' # `User-Agent` (for nodejs)
  exports.new = (options) -> new Octokit(options)

# If requirejs is detected then define this module
else if @define?
  # Define both 'github' and 'octokit' for transition
  for moduleName in ['github', 'octokit']
    # If the browser has the native Base64 encode function `btoa` use it.
    # Otherwise, try to use the javascript Base64 code.
    if @btoa
      @define moduleName, ['underscore', 'jquery'], (_, jQuery) ->
        return makeOctokit _, jQuery, @btoa
    else
      @define moduleName, ['underscore', 'jquery', 'base64'], (_, jQuery, Base64) ->
        return makeOctokit _, jQuery, Base64.encode

# If a global jQuery and underscore is loaded then use it
else if @_ and @jQuery and (@btoa or @Base64)
  # Use the `btoa` function if it is defined (Webkit/Mozilla) and fail back to
  # `Base64.encode` otherwise (IE)
  encode = @btoa or @Base64.encode
  Octokit = makeOctokit @_, @jQuery, encode
  # Assign to `Octokit` and `Github` global for backwards compatibility
  @Octokit ?= Octokit
  @Github ?= Octokit


# Otherwise, throw an error
else
  err = (msg) ->
    console?.error? msg
    throw msg

  err 'Underscore not included' if not @_
  err 'jQuery not included' if not @jQuery
  err 'Base64 not included' if not @Base64 and not @btoa
