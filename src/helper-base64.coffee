@define ?= (name, deps, cb) -> cb (require(dep) for dep in deps)...
@define 'octokit/helper-base64', [], () ->

  if module?.exports
    module.exports = (str) ->
      buffer = new Buffer(str, 'binary')
      return buffer.toString('base64')

  else
    return @btoa

