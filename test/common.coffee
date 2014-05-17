makeTests = (assert, expect, base64encode, Octokit) ->

  USERNAME = 'octokit-test'
  TOKEN = 'dca7f85a5911df8e9b7aeb4c5be8f5f50806ac49'

  ORG_NAME = 'octokit-test-org'

  REPO_USER = USERNAME
  REPO_NAME = 'octokit-test-repo' # Cannot use '.' because najax does not like it

  REPO_HOMEPAGE = 'https:/github.com/philschatz/octokit.js'
  OTHER_HOMEPAGE = 'http://example.com'

  OTHER_USERNAME = 'octokit-test2'

  DEFAULT_BRANCH = 'master'

  LONG_TIMEOUT = 10 * 1000 # 10 seconds
  SHORT_TIMEOUT = 5 * 1000 # 5 seconds


  IS_NODE = !! module?

  some = (arr, fn) ->
    for entry in arr
      do (entry) ->
        if fn(entry) == true
          return true
    return false

  trapFail = (promise) ->
    onError = (err) ->
      console.error(JSON.stringify(err))
      assert.catch(err)
    # Depending on the Promise implementation the fail method could be:
    # - `.catch` (native Promise)
    # - `.fail` (jQuery or angularjs)
    promise.catch?(onError) or promise.fail(onError)
    return promise

  helper1 = (done, promise, func) ->
    return trapFail(promise)
    .then(func)
    .then () -> done()

  helper2 = (promise, func) ->
    return trapFail(promise)
    .then(func)

  arrayContainsKey = (arr, key, value) ->
    some arr, (entry) ->
      return entry[key] == value

  GH = 'octo'
  REPO = 'myRepo'
  USER = 'someUser'
  ME = 'myUser'
  BRANCH = 'BRANCH'
  ANOTHER_USER = 'ANOTHER_USER'
  ORG = 'someOrg'
  GIST = 'someGist'
  ISSUE = 'someIssue'
  COMMENT = 'someComment'

  STATE = {}


  describe "#{GH} = new Octokit({token: ...})", () ->
    @timeout(LONG_TIMEOUT)

    stringifyAry = (args) ->
      args = [args] unless Array.isArray(args)
      return '' if not args.length
      arr = (JSON.stringify(arg) for arg in args)
      return arr.join(', ')

    itIs = (obj, msg, args, cb) ->
      code = ''
      isFuncArgs = false
      for arg in args
        if isFuncArgs
          code += "(#{stringifyAry(arg)})"
        else
          code += '.' + arg

        isFuncArgs = !isFuncArgs

      code += '()' if isFuncArgs


      it "#{obj}#{code}", (done) ->
        context = STATE[obj]
        isFuncArgs = false # Every other arg is a function arg
        for arg in args
          if isFuncArgs
            arg = [arg] unless Array.isArray(arg)
            context = context(arg...)
          else
            names = arg.split('.')
            for field in names
              context = context[field]

          isFuncArgs = !isFuncArgs

        # If the last arg was something like 'fetch' then
        if isFuncArgs
          helper1 done, context(), cb
        else
          helper1 done, context, cb


    itIsOk = (obj, args...) ->
      itIs obj, '', args, (val) -> expect(val).to.be.ok

    itIsArray = (obj, args...) ->
      itIs obj, ' yields Array', args, (val) ->
        expect(val).to.be.an.array

    itIsFalse = (obj, args...) ->
      itIs obj, ' yields False', args, (val) ->
        expect(val).to.be.false

    before () ->
      options =
        token: TOKEN
        # PhantomJS does not support the `PATCH` verb yet.
        # See https://github.com/ariya/phantomjs/issues/11384 for updates
        usePostInsteadOfPatch:true

      options.useETags = false if IS_NODE

      STATE[GH] = new Octokit(options)

    describe 'Miscellaneous APIs', () ->
      itIsOk(GH, 'zen.read')
      itIsOk(GH, 'emojis.fetch')
      itIsOk(GH, 'gitignore.templates.fetch')
      itIsOk(GH, 'gitignore.templates', 'C', 'read')
      # itIsOk(GH, 'markdown.create', [{text:'# Hello There'}, true])
      itIsOk(GH, 'meta.fetch')
      itIsOk(GH, 'rateLimit.fetch')

    itIsArray(GH, 'users.fetch')
    itIsArray(GH, 'gists.public.fetch')
    # itIsArray(GH, 'global.events')
    # itIsArray(GH, 'global.notifications')

    itIsArray(GH, 'search.repositories.fetch', {q:'github'})
    # itIsArray(GH, 'search.code.fetch', {q:'github'})
    itIsArray(GH, 'search.issues.fetch', {q:'github'})
    itIsArray(GH, 'search.users.fetch', {q:'github'})

    itIsOk(GH, 'users', REPO_USER, 'fetch')
    itIsOk(GH, 'orgs', ORG_NAME, 'fetch')
    itIsOk(GH, 'repos', [REPO_USER, REPO_NAME], 'fetch')
    itIsArray(GH, 'issues.fetch')


    describe 'Paged Results', () ->

      it "#{GH}.gists.public.fetch().then(results) -> results.nextPage()", (done) ->
        trapFail(STATE[GH].gists.public.fetch())
        .then (results) ->
          results.nextPage()
          .then (moreResults) ->
            done()

    describe "#{REPO} = #{GH}.repos(OWNER, NAME)", () ->

      before () ->
        STATE[REPO] = STATE[GH].repos(REPO_USER, REPO_NAME)

      itIsOk(REPO, 'fetch')

      # Accessors for methods generated from URL patterns
      itIsArray(REPO, 'collaborators.fetch')
      itIsArray(REPO, 'hooks.fetch')
      itIsArray(REPO, 'assignees.fetch')
      itIsArray(REPO, 'branches.fetch')
      itIsArray(REPO, 'contributors.fetch')
      itIsArray(REPO, 'subscribers.fetch')
      itIsArray(REPO, 'subscription.fetch')
      itIsArray(REPO, 'comments.fetch')
      itIsArray(REPO, 'downloads.fetch')
      itIsArray(REPO, 'milestones.fetch')
      itIsArray(REPO, 'labels.fetch')
      # itIsArray(REPO, 'stargazers.fetch')
      itIsArray(REPO, 'issues.fetch')
      itIsArray(REPO, 'issues.events.fetch')
      itIsArray(REPO, 'issues.comments.fetch')
      # itIsArray(REPO, 'issues.comments', commentId, 'fetch')

      itIsOk(REPO, 'issues.create', {title: 'Test Issue'})
      itIsOk(REPO, 'issues', 1, 'fetch')

      describe "#{REPO}.git... (Git Data)", () ->

        itIsArray(REPO, 'git.refs.fetch')
        # itIsArray(REPO, 'git.refs.tags.fetch')    This repo does not have any tags: TODO: create a tag
        itIsArray(REPO, 'git.refs.heads.fetch')

        # itIsOk(REPO, 'git.tags.create', {tag:'test-tag', message:'Test tag for units', ...})
        # itIsOk(REPO, 'git.tags.one', 'test-tag')
        itIsOk(REPO, 'git.trees', 'c18ba7dc333132c035a980153eb520db6e813d57', 'fetch')
        # itIsOk(REPO, 'git.trees.create', {tree: [sha], base_tree: sha})


        it '.git.blobs.create("Hello")   and .blobs(sha).read()', (done) ->
          STATE[REPO].git.blobs.create({content:'Hello', encoding:'utf-8'})
          .then ({sha}) ->
            expect(sha).to.be.ok
            STATE[REPO].git.blobs(sha).read()
            .then (v) ->
              expect(v).to.equal('Hello')
              done()

        it '.git.blobs.create(...) and .blobs(...).readBinary()', (done) ->
          STATE[REPO].git.blobs.create({content:base64encode('Hello'), encoding: 'base64'})
          .then ({sha}) ->
            expect(sha).to.be.ok
            STATE[REPO].git.blobs(sha).readBinary()
            .then (v) ->
              expect(v).to.have.string('Hello')

              done()
              # Make sure the library does not just ignore the isBase64 flag
              # TODO: This is commented because caching is only based on the path, not the flags (or the verb)
              # STATE[REPO].git.blobs.one(sha)
              # .then (v) ->
              #   expect(v).to.not.have.string('Hello')
              #   done()



      describe 'Collaborator changes', () ->
        it 'gets a list of collaborators', (done) ->
          trapFail(STATE[REPO].collaborators.fetch())
          .then (v) -> expect(v).to.be.an.array; done()

        it 'tests membership', (done) ->
          trapFail(STATE[REPO].collaborators.contains(REPO_USER))
          .then (v) -> expect(v).to.be.true; done()

        it 'adds and removes a collaborator', (done) ->
          trapFail(STATE[REPO].collaborators(OTHER_USERNAME).add())
          .then (v) ->
            expect(v).to.be.ok
            trapFail(STATE[REPO].collaborators(OTHER_USERNAME).remove())
            .then (v) ->
              expect(v).to.be.true
              done()


    describe "#{USER} = #{GH}.users(USERNAME)", () ->

      before () ->
        STATE[USER] = STATE[GH].users(USERNAME)

      itIsOk(USER, 'fetch')
      itIsArray(USER, 'repos.fetch')
      itIsArray(USER, 'orgs.fetch')
      itIsArray(USER, 'gists.fetch')
      itIsArray(USER, 'followers.fetch')
      itIsArray(USER, 'following.fetch')
      itIsFalse(USER, 'following.contains', 'defunkt')
      itIsArray(USER, 'keys.fetch')
      itIsArray(USER, 'events.fetch')
      itIsArray(USER, 'receivedEvents.fetch')


    describe "#{ORG} = #{GH}.orgs(ORG_NAME)", () ->

      before () ->
        STATE[ORG] = STATE[GH].orgs(ORG_NAME)

      itIsArray(ORG, 'fetch')
      itIsArray(ORG, 'members.fetch')
      itIsArray(ORG, 'repos.fetch')
      itIsArray(ORG, 'issues.fetch')


    describe "#{ME} = #{GH}.me (the authenticated user)", () ->

      before () ->
        STATE[ME] = STATE[GH].me

      # itIsOk(ME, 'fetch')

      itIsArray(ME, 'repos.fetch')
      itIsArray(ME, 'orgs.fetch')
      itIsArray(ME, 'followers.fetch')
      itIsArray(ME, 'following.fetch')
      itIsFalse(ME, 'following.contains', 'defunkt')
      itIsArray(ME, 'emails.fetch')
      itIsFalse(ME, 'emails.contains', 'invalid@email.com')
      # itIsArray(ME, 'keys.all')
      # itIsFalse(ME, 'keys.is', 'invalid-key')

      itIsArray(ME, 'issues.fetch')

      # itIsArray(ME, 'starred.all') Not enough permission


      describe 'Multistep operations', () ->

        it '.starred.add(OWNER, REPO), .starred.is(...), and then .starred.remove(...)', (done) ->
          trapFail(STATE[ME].starred(REPO_USER, REPO_NAME).add())
          .then () ->
            STATE[ME].starred.contains(REPO_USER, REPO_NAME)
            .then (isStarred) ->
              expect(isStarred).to.be.true
              STATE[ME].starred(REPO_USER, REPO_NAME).remove()
              .then (v) ->
                expect(v).to.be.true
                done()


    describe "#{GIST} = #{GH}.gist(GIST_ID)", () ->

      before (done) ->

        # Create a Test Gist for all the tests
        config =
          description: "Test Gist"
          'public': false
          files:
            "hello.txt":
              content: "Hello World"

        STATE[GH].gists.create(config)
        .then (gist) ->
          STATE[GIST] = gist
          done()

      # itIsOk(GIST, 'fetch')

      # itIsArray(GIST, 'forks.all')
      it 'can be .starred.add() and .starred.remove()', (done) ->
        STATE[GIST].star.add()
        .then () ->
          STATE[GIST].star.remove()
          .then () ->
            done()



    describe "#{ISSUE} = #{REPO}.issues(1)", () ->
      before () ->
        STATE[ISSUE] = STATE[REPO].issues(1)

      itIsOk(ISSUE, 'fetch')
      itIsOk(ISSUE, 'update', {title: 'New Title', state: 'closed'})

      describe 'Comment methods (Some are on the repo, issue, or comment)', () ->

        itIsArray(ISSUE, 'comments.fetch')
        itIsOk(ISSUE, 'comments.create', {body: 'Test comment'})
        # NOTE: Comment updating is awkward because it's on the repo, not a specific issue.
        # itIsOk(REPO, 'issues.comments.update', 43218269, {body: 'Test comment updated'})
        itIsOk(REPO, 'issues.comments', 43218269, 'fetch')

        it 'comment.issue()', (done) ->
          trapFail(STATE[REPO].issues.comments(43218269).fetch())
          .then (comment) ->
            comment.issue()
            .then (v) ->
              done()





    #   describe 'Initially:', () ->
    #     it 'has one commit', (done) ->
    #       trapFail(STATE[REPO].getCommits())
    #       .then (val) ->
    #         expect(val).to.have.length(1)
    #         done()

    #     it 'has one branch', (done) ->
    #       trapFail(STATE[REPO].getBranches())
    #       .then (branches) ->
    #         expect(branches).to.have.length(1)
    #         done()

    #   describe 'Writing file(s):', () ->
    #     it 'commits a single text file', (done) ->
    #       FILE_PATH = 'test.txt'
    #       FILE_TEXT = 'Hello there'

    #       trapFail(STATE[BRANCH].write(FILE_PATH, FILE_TEXT))
    #       .then (sha) ->
    #         # Read the file back
    #         trapFail(STATE[BRANCH].read(FILE_PATH))
    #         .then (val) ->
    #           expect(val.content).to.equal(FILE_TEXT)
    #           PREV_SHA = val.sha
    #           done()

    #     it 'removes a single file', (done) ->
    #       FILE_PATH = 'test.txt'
    #       trapFail(STATE[BRANCH].remove(FILE_PATH))
    #       .then () ->
    #         done()

    #     it 'commits multiple files at once (including binary ones)', (done) ->
    #       FILE1 = 'testdir/test1.txt'
    #       FILE2 = 'testdir/test2.txt'
    #       BINARY_DATA = 'Ahoy!'
    #       contents = {}
    #       contents[FILE1] = 'Hello World!'
    #       contents[FILE2] = {content:btoa(BINARY_DATA), isBase64:true}

    #       trapFail(STATE[BRANCH].writeMany(contents))
    #       .then () ->
    #         # Read the files and verify they were added
    #         trapFail(STATE[BRANCH].read(FILE1))
    #         .then (val) ->
    #           expect(val.content).to.equal(contents[FILE1])
    #           trapFail(STATE[BRANCH].read(FILE2))
    #           .then (val) ->
    #             expect(val.content).to.equal(contents[FILE2].content)
    #             done()

    #     it 'should have created 4 commits (3 + the initial)', (done) ->
    #       helper1 done, STATE[REPO].getCommits(), (commits) ->
    #         expect(commits).to.have.length(4)

    #   describe 'Collaborators:', () ->
    #     it 'initially should have only 1 collaborator', (done) ->
    #       helper1 done, STATE[REPO].getCollaborators(), (collaborators) ->
    #         expect(collaborators).to.have.length(1)

    #     it 'initially the collaborator should be [USERNAME]', (done) ->
    #       helper1 done, STATE[REPO].isCollaborator(USERNAME), (canCollaborate) ->
    #         expect(canCollaborate).to.be.true

    #     it 'the current user should be able to collaborate', (done) ->
    #       helper1 done, STATE[REPO].canCollaborate(), (canCollaborate) ->
    #         expect(canCollaborate).to.be.true

    #     it 'should be able to add and remove a collaborator', (done) ->
    #       helper2 STATE[REPO].addCollaborator(OTHER_USERNAME), (added) ->
    #         expect(added).to.be.true

    #         helper2 STATE[REPO].isCollaborator(OTHER_USERNAME), (canCollaborate) ->
    #           expect(canCollaborate).to.be.true

    #           helper2 STATE[REPO].removeCollaborator(OTHER_USERNAME), (removed) ->
    #             expect(removed).to.be.true

    #             helper1 done, STATE[REPO].isCollaborator(OTHER_USERNAME), (canCollaborate) ->
    #               expect(canCollaborate).to.be.false

    #   describe 'Editing Repository:', () ->
    #     it 'initially the repository homepage should be [REPO_HOMEPAGE]', (done) ->
    #       helper1 done, STATE[REPO].getInfo(), (info) ->
    #         expect(info.homepage).to.equal(REPO_HOMEPAGE)

    #     it 'should be able to edit the repo homepage', (done) ->
    #       helper2 STATE[REPO].updateInfo({name: REPO_NAME, homepage: OTHER_HOMEPAGE}), ->

    #         helper1 done, STATE[REPO].getInfo(), (info) ->
    #           expect(info.homepage).to.equal(OTHER_HOMEPAGE)

    #     it 'changing the default branch should not explode', (done) ->
    #       helper1 done, STATE[REPO].setDefaultBranch(DEFAULT_BRANCH), (result) ->
    #         expect(result.default_branch).to.equal(DEFAULT_BRANCH)

    #   describe 'fetch organization', () ->
    #     it 'should be able to fetch organization info', (done) ->

    #       helper1 done, STATE[GH].getOrg(ORG_NAME).getInfo(), (info) ->
    #         expect(info.login).to.equal(ORG_NAME)

    #   describe 'Releases', () ->
    #     it 'should be able to get releases', (done) ->

    #       helper1 done, STATE[REPO].getReleases(), (releases) ->
    #         expect(releases).to.have.length(0)

    #   describe 'Events:', () ->
    #     itIsOk(REPO, 'getEvents')
    #     itIsOk(REPO, 'getIssueEvents')
    #     itIsOk(REPO, 'getNetworkEvents')
    #     #itIsOk(REPO, 'getNotifications')

    #   describe 'Misc:', () ->
    #     itIsOk(REPO, 'getHooks')
    #     itIsOk(REPO, 'getLanguages')
    #     itIsOk(REPO, 'getInfo')


    # describe 'Users:', () ->

    #   describe 'Current User:', () ->

    #     describe 'Methods for all Users:', () ->
    #       #itIsOk(USER, 'getNotifications')
    #       itIsOk(USER, 'getInfo')
    #       itIsOk(USER, 'getRepos')
    #       itIsOk(USER, 'getOrgs')
    #       itIsOk(USER, 'getGists')
    #       itIsOk(USER, 'getFollowers')
    #       itIsOk(USER, 'getFollowing')
    #       #(USER, 'isFollowing')
    #       # itIsOk(USER, 'getPublicKeys')
    #       # itIsOk(USER, 'getReceivedEvents')
    #       # itIsOk(USER, 'getEvents')

    #     describe 'Methods only for authenticated user:', () ->
    #       #(USER, 'updateInfo(options')
    #       itIsOk(USER, 'getGists')
    #       #(USER, 'follow(username)')
    #       #(USER, 'unfollow(username)')
    #       itIsOk(USER, 'getEmails')
    #       #(USER, 'addEmail(emails)')
    #       #(USER, 'removeEmail(emails)')
    #       #(USER, 'getPublicKey(id)')
    #       #(USER, 'addPublicKey(title, key)')
    #       #(USER, 'updatePublicKey(id, options)')

    #   describe 'Another User:', () ->
    #     before () ->
    #       STATE[ANOTHER_USER] = STATE[GH].getUser(OTHER_USERNAME)

    #     # itIsOk(user, 'getNotifications')
    #     itIsOk(ANOTHER_USER, 'getInfo')
    #     itIsOk(ANOTHER_USER, 'getRepos')
    #     itIsOk(ANOTHER_USER, 'getOrgs')
    #     itIsOk(ANOTHER_USER, 'getGists')
    #     itIsOk(ANOTHER_USER, 'getFollowers')
    #     itIsOk(ANOTHER_USER, 'getFollowing')
    #     #(ANOTHER_USER, 'isFollowing')
    #     itIsOk(ANOTHER_USER, 'getPublicKeys')
    #     itIsOk(ANOTHER_USER, 'getReceivedEvents')
    #     itIsOk(ANOTHER_USER, 'getEvents')


if exports?
  exports.makeTests = makeTests
else
  @makeTests = makeTests
