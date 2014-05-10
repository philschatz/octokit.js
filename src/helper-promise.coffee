@define ?= (name, deps, cb) -> cb (require(dep) for dep in deps)...
@define 'octokit/helper-promise', [], () ->

  if module?.exports
    # Use native promises if Harmony is on
    Promise         = @Promise or require('es6-promise').Promise
    newPromise = (fn) -> return new Promise(fn)
    allPromises = (promises) -> return Promise.all(promises)

    module.exports = {newPromise, allPromises}

  else

    # Determine the correct Promise factory.
    # Try to use libraries before native Promises since most Promise users
    # are already using a library.
    #
    # Try in the following order:
    # - Q Promise
    # - angularjs Promise
    # - jQuery Promise
    # - native Promise or a polyfill
    if @Q
      newPromise = (fn) =>
        deferred = @Q.defer()
        resolve = (val) -> deferred.resolve(val)
        reject  = (err) -> deferred.reject(err)
        fn(resolve, reject)
        return deferred.promise
      allPromises = (promises) -> @Q.all(promises)
    else if @angular
      newPromise = null
      allPromises = null

      # Details on Angular Promises: http://docs.angularjs.org/api/ng/service/$q
      injector = angular.injector(['ng'])
      injector.invoke ($q) ->
        newPromise = (fn) ->
          deferred = $q.defer()
          resolve = (val) -> deferred.resolve(val)
          reject  = (err) -> deferred.reject(err)
          fn(resolve, reject)
          return deferred.promise
        allPromises = (promises) -> $q.all(promises)
    else if @jQuery?.Deferred
      newPromise = (fn) =>
        promise = @jQuery.Deferred()
        resolve = (val) -> promise.resolve(val)
        reject  = (val) -> promise.reject(val)
        fn(resolve, reject)
        return promise.promise()
      allPromises = (promises) =>
        # `jQuery.when` is a little odd.
        # - It accepts each promise as an argument (instead of an array of promises)
        # - Each resolved value is an argument (instead of an array of values)
        #
        # So, convert the array of promises to args and then the resolved args to an array
        return @jQuery.when(promises...).then((promises...) -> return promises)
    else if @Promise
      newPromise = (fn) => return new @Promise (resolve, reject) ->
        # Some browsers (like node-webkit 0.8.6) contain an older implementation
        # of Promises that provide 1 argument (a `PromiseResolver`).
        if resolve.fulfill
          fn(resolve.resolve.bind(resolve), resolve.reject.bind(resolve))
        else
          fn(arguments...)
      allPromises = @Promise.all

    else
      # Otherwise, throw an error
      err = (msg) ->
        console?.error?(msg)
        throw new Error(msg)
      err('A Promise API was not found. Supported libraries that have Promises are jQuery, angularjs, and https://github.com/jakearchibald/es6-promise')

    return {newPromise, allPromises}
