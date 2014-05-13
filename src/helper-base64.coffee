define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/helper-base64', [], () ->

  if module?.exports
    module.exports = (str) ->
      buffer = new Buffer(str, 'binary')
      return buffer.toString('base64')

  else
    return @btoa

