define = window?.define or (name, deps, cb) -> cb (require(dep.replace('cs!octokit-part/', './')) for dep in deps)...
define 'octokit-part/grammar', [], () ->

  TREE_OPTIONS =
    'zen'         : false
    'users'       : false
    'issues'      : false
    'gists'       : false
    'emojis'      : false
    'meta'        : false
    'rate_limit'  : false
    'feeds'       : false
    'events'      : false
    'gitignore':
      'templates' : false
    'user':
      'repos'     : false
      'orgs'      : false
      'followers' : false
      'following' : false
      'emails'    : false
      'issues'    : false
      'starred'   : false
    'orgs':
      'repos'     : false
      'issues'    : false
      'members'   : false
    'users':
      'repos'     : false
      'orgs'      : false
      'gists'     : false
      'followers' : false
      'following' : false
      'keys'      : false
      'events'    : false
      'received_events': false
    'search':
      'repositories' : false
      'issues'    : false
      'users'     : false
      'code'      : false
    'gists':
      'public'    : false
      'star'      : false
    'repos':
      'readme'        : false
      'hooks':
        'tests'       : false
      'assignees'     : false
      'languages'     : false
      'branches'      : false
      'contributors'  : false
      'subscribers'   : false
      'subscription'  : false
      'comments'      : false
      'downloads'     : false
      'milestones'    : false
      'labels'        : false
      'releases'      : false
      'events'        : false
      'commits'       : false
      'contents'      : false
      'collaborators' : false
      'issues':
        'events'      : false
        'comments'    : false
      'git':
        'refs':
          'heads'     : false
        'trees'       : false
        'blobs'       : false
        'commits'     : false
      'stats':
        'contributors'    : false
        'commit_activity' : false
        'code_frequency'  : false
        'participation'   : false
        'punch_card'      : false



  OBJECT_MATCHER =
    'repos': /// ^
      (https?://[^/]+)? # Optional protocol, host, and port
      (/api/v3)?        # Optional API root for enterprise GitHub users
      /repos/ [^/]+ / [^/]+
      $
    ///
    'gists': /// ^ (https?://[^/]+)? (/api/v3)?
      /gists/ [^/]+
      $
    ///
    'issues': /// ^ (https?://[^/]+)? (/api/v3)?
      /repos/ [^/]+ / [^/]+
      /(issues|pulls) [^/]+
      $
    ///
    'users': /// ^ (https?://[^/]+)? (/api/v3)?
      /users/ [^/]+
      $
    ///
    'orgs': /// ^ (https?://[^/]+)? (/api/v3)?
      /orgs/ [^/]+
      $
    ///

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
      | events
      | gitignore/templates (/[^/]+)?

      | user
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
            readme
          | hooks
          | hooks /[^/]+
          | hooks /[^/]+ /tests
          | assignees
          | languages
          | branches
          | contributors
          | subscribers
          | subscription
          | comments
          | downloads
          | milestones
          | labels
          | releases
          | events
          | commits
          | contents (/[^/]+)* # The path is allowed in the URL
          | collaborators (/[^/]+)?
          | issues
          | issues/ (
                events
              | comments (/[0-9]+)?
              | [0-9]+ (/comments)?
              )

          | git/ (
                refs
              | refs / heads (/[^/]+)?
              | trees (/[^/]+)? # Can be a sha or a branch name
              | blobs (/[a-f0-9]{40}$)?
              | commits (/[a-f0-9]{40}$)?
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


  module?.exports = {TREE_OPTIONS, OBJECT_MATCHER, URL_VALIDATOR}
  return {TREE_OPTIONS, OBJECT_MATCHER, URL_VALIDATOR}
