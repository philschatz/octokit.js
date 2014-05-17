define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/replacer', ['cs!octokit-part/plus'], (plus) ->

  # require('underscore-plus')
  plus =
    camelize: (string) ->
      if string
        string.replace /[_-]+(\w)/g, (m) -> m[1].toUpperCase()
      else
        ''

    dasherize: (string) ->
      return '' unless string

      string = string[0].toLowerCase() + string[1..]
      string.replace /([A-Z])|(_)/g, (m, letter) ->
        if letter
          '-' + letter.toLowerCase()
        else
          '-'

  module?.exports = plus
  return plus
