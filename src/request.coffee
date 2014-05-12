@define ?= (name, deps, cb) -> cb (require(dep) for dep in deps)...
@define 'octokit/request', [
  'xmlhttprequest'
  './helper-promise'
  './helper-base64'
], (xmlhttprequest, {newPromise, allPromises}, base64encode) ->

  XMLHttpRequest = xmlhttprequest.XMLHttpRequest

  userAgent = 'octokit' if module?

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

  Request = (clientOptions={}) ->

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



  module?.exports = Request
  return Request
