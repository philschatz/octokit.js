makeTests = (assert, expect, btoa, Octokit) ->

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

  describe 'octo = new Octokit({token: ...})', () ->
    @timeout(LONG_TIMEOUT)

    GH = 'GH'
    REPO = 'REPO'
    USER = 'USER'
    ME = 'ME'
    BRANCH = 'BRANCH'
    ANOTHER_USER = 'ANOTHER_USER'
    ORG = 'ORG'
    GIST = 'GIST'
    ISSUE = 'ISSUE'

    STATE = {}

    stringifyAry = (args...) ->
      return '' if not args.length
      arr = (JSON.stringify(arg) for arg in args)
      return arr.join(', ')

    itIsOk = (obj, funcNames, args...) ->
      it ".#{funcNames}(#{stringifyAry(args...)})", (done) ->
        names = funcNames.split('.')
        context = STATE[obj]
        for field in names
          context = context[field]
        helper1 done, context(args...), (val) ->
          expect(val).to.be.ok

    itIsArray = (obj, funcNames, args...) ->
      it ".#{funcNames}(#{stringifyAry(args...)}) yields Array", (done) ->
        names = funcNames.split('.')
        context = STATE[obj]
        for field in names
          context = context[field]
        helper1 done, context(args...), (val) ->
          expect(val).to.be.an.array

    itIsFalse = (obj, funcNames, args...) ->
      it ".#{funcNames}(#{stringifyAry(args...)}) yields false", (done) ->
        names = funcNames.split('.')
        context = STATE[obj]
        for field in names
          context = context[field]
        helper1 done, context(args...), (val) ->
          expect(val).to.be.false

    before () ->
      options =
        token: TOKEN
        # PhantomJS does not support the `PATCH` verb yet.
        # See https://github.com/ariya/phantomjs/issues/11384 for updates
        usePostInsteadOfPatch:true

      options.useETags = false if IS_NODE

      STATE[GH] = new Octokit(options)

    itIsOk(GH, 'global.zen')
    itIsArray(GH, 'global.users')
    itIsArray(GH, 'global.gists')
    # itIsArray(GH, 'global.events')
    # itIsArray(GH, 'global.notifications')

    itIsArray(GH, 'search.repos', {q:'github'})
    # itIsArray(GH, 'search.code', {q:'github'})
    itIsArray(GH, 'search.issues', {q:'github'})
    itIsArray(GH, 'search.users', {q:'github'})

    itIsOk(GH, 'user', REPO_USER)
    itIsOk(GH, 'org', ORG_NAME)
    itIsOk(GH, 'repo', REPO_USER, REPO_NAME)
    itIsArray(GH, 'issues')
    itIsArray(GH, 'gists.all')


    describe '.repo(REPO_USER, REPO_NAME)', () ->

      before (done) ->
        STATE[GH].repo(REPO_USER, REPO_NAME)
        .then (repo) ->
          STATE[REPO] = repo
          done()

      describe 'Accessors for methods generated from URL patterns', () ->
        @timeout(LONG_TIMEOUT)
        itIsArray(REPO, 'collaborators.all')
        itIsArray(REPO, 'hooks.all')
        itIsArray(REPO, 'assignees.all')
        itIsArray(REPO, 'branches')
        itIsArray(REPO, 'contributors')
        itIsArray(REPO, 'subscribers')
        itIsArray(REPO, 'subscription')
        itIsArray(REPO, 'comments')
        itIsArray(REPO, 'downloads')
        itIsArray(REPO, 'milestones')
        itIsArray(REPO, 'labels')
        # itIsArray(REPO, 'stargazers')
        itIsArray(REPO, 'issues.all')
        itIsArray(REPO, 'issues.events')
        itIsArray(REPO, 'issues.comments.all')
        # itIsArray(REPO, 'issues.comments.one', commentId)

        itIsOk(REPO, 'issues.create', {title: 'Test Issue'})
        itIsOk(REPO, 'issues.one', 1)

      describe '.git (Git Data)', () ->

        itIsArray(REPO, 'git.refs.all')
        # itIsArray(REPO, 'git.refs.tags')    This repo does not have any tags: TODO: create a tag
        itIsArray(REPO, 'git.refs.heads')

        # itIsOk(REPO, 'git.tags.create', {tag:'test-tag', message:'Test tag for units', ...})
        # itIsOk(REPO, 'git.tags.one', 'test-tag')
        itIsOk(REPO, 'git.trees.one', 'c18ba7dc333132c035a980153eb520db6e813d57')
        # itIsOk(REPO, 'git.trees.create', {tree: [sha], base_tree: sha})


        it '.git.blobs.create("Hello")   and .blobs.one(sha)', (done) ->
          STATE[REPO].git.blobs.create('Hello')
          .then ({sha}) ->
            expect(sha).to.be.ok
            STATE[REPO].git.blobs.one(sha)
            .then (v) ->
              expect(v).to.equal('Hello')
              done()

        it '.git.blobs.create(..., true) and .blobs.one(..., true) (binary flag)', (done) ->
          STATE[REPO].git.blobs.create('Hello', true)
          .then ({sha}) ->
            expect(sha).to.be.ok
            STATE[REPO].git.blobs.one(sha, true)
            .then (v) ->
              expect(v).to.have.string('Hello')

              done()
              # Make sure the library does not just ignore the isBinary flag
              # TODO: This is commented because caching is only based on the path, not the flags (or the verb)
              # STATE[REPO].git.blobs.one(sha)
              # .then (v) ->
              #   expect(v).to.not.have.string('Hello')
              #   done()



      describe 'Collaborator changes', () ->
        it 'gets a list of collaborators', (done) ->
          trapFail(STATE[REPO].collaborators.all())
          .then (v) -> expect(v).to.be.an.array; done()

        it 'tests membership', (done) ->
          trapFail(STATE[REPO].collaborators.is(REPO_USER))
          .then (v) -> expect(v).to.be.true; done()

        it 'adds and removes a collaborator', (done) ->
          trapFail(STATE[REPO].collaborators.add(OTHER_USERNAME))
          .then (v) ->
            expect(v).to.be.ok
            trapFail(STATE[REPO].collaborators.remove(OTHER_USERNAME))
            .then (v) ->
              expect(v).to.be.true
              done()


    describe '.user(USERNAME)', () ->

      before (done) ->
        STATE[GH].user(USERNAME)
        .then (v) ->
          STATE[USER] = v
          done()

      itIsArray(USER, 'repos')
      itIsArray(USER, 'orgs')
      itIsArray(USER, 'gists')
      itIsArray(USER, 'followers')
      itIsArray(USER, 'following.all')
      itIsFalse(USER, 'following.is', 'defunkt')
      itIsArray(USER, 'keys')
      itIsArray(USER, 'events')
      itIsArray(USER, 'receivedEvents')


    describe '.org(ORG_NAME)', () ->

      before (done) ->
        STATE[GH].org(ORG_NAME)
        .then (v) ->
          STATE[ORG] = v
          done()

      itIsArray(ORG, 'members.all')
      itIsArray(ORG, 'repos.all')
      itIsArray(ORG, 'issues')


    describe '.me', () ->

      before () ->
        STATE[ME] = STATE[GH].me

      itIsArray(ME, 'repos')
      itIsArray(ME, 'orgs')
      itIsArray(ME, 'followers')
      itIsArray(ME, 'following.all')
      itIsFalse(ME, 'following.is', 'defunkt')
      itIsArray(ME, 'emails.all')
      itIsFalse(ME, 'emails.is', 'invalid@email.com')
      # itIsArray(ME, 'keys.all')
      # itIsFalse(ME, 'keys.is', 'invalid-key')

      itIsArray(ME, 'issues')

      # itIsArray(ME, 'starred.all') Not enough permission


      describe 'Multistep operations', () ->

        it '.starred.add(OWNER, REPO), .starred.is(...), and then .starred.remove(...)', (done) ->
          trapFail(STATE[ME].starred.add(REPO_USER, REPO_NAME))
          .then () ->
            STATE[ME].starred.is(REPO_USER, REPO_NAME)
            .then (isStarred) ->
              expect(isStarred).to.be.true
              STATE[ME].starred.remove(REPO_USER, REPO_NAME)
              .then (v) ->
                expect(v).to.be.true
                done()


    describe '.gist(GIST_ID)', () ->

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

      # itIsArray(GIST, 'forks.all')
      it 'can be .starred.add() and .starred.remove()', (done) ->
        STATE[GIST].starred.add()
        .then () ->
          STATE[GIST].starred.remove()
          .then () ->
            done()



    describe 'issue (Issues in a Repository)', (done) ->
      before (done) ->
        STATE[REPO].issues.one(1)
        .then (issue) ->
          STATE[ISSUE] = issue
          done()

      itIsOk(ISSUE, 'update', {title: 'New Title', state: 'closed'})
      itIsOk(ISSUE, 'comments.all')
      itIsOk(ISSUE, 'comments.create', {body: 'Test comment'})
      # NOTE: Comment updating is awkward because it's on the repo, not a specific issue.
      itIsOk(REPO, 'issues.comments.update', 43218269, {body: 'Test comment updated'})






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
