ThreadStats =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Thread Stats']

    countHTML = <%= html('<span id="post-count">?</span> / <span id="file-count">?</span> / <span id="ip-count">?</span>') %>
    countHTML = <%= html('&{countHTML} / <span id="page-count">?</span>') %> if Conf['Page Count in Stats']

    if Conf['Updater and Stats in Header']
      @dialog = sc = $.el 'span',
        id:        'thread-stats'
        title: 'Post Count / File Count / IP Count' + (if Conf["Page Count in Stats"] then " / Page Count" else "")
      $.extend sc, countHTML
      $.ready ->
        Header.addShortcut sc
    else
      @dialog = sc = UI.dialog 'thread-stats', 'bottom: 0px; right: 0px;',
        <%= html('<div class="move" title="Post Count / File Count / IP Count${Conf["Page Count in Stats"] ? " / Page Count" : ""}">&{countHTML}</div>') %>
      $.ready =>
        $.add d.body, sc

    @postCountEl = $ '#post-count', sc
    @fileCountEl = $ '#file-count', sc
    @ipCountEl   = $ '#ip-count',   sc
    @pageCountEl = $ '#page-count', sc

    Thread.callbacks.push
      name: 'Thread Stats'
      cb:   @node

  node: ->
    postCount = 0
    fileCount = 0
    @posts.forEach (post) ->
      postCount++
      fileCount++ if post.file
      ThreadStats.lastPost = post.info.date if Conf["Page Count in Stats"]
    for script in $$ 'script[type="text/javascript"]:not([src])', d.head
      if m = script.textContent.match /\bvar unique_ips = (\d+);/
        ipCount = +m[1]
        break
    ThreadStats.thread = @
    ThreadStats.fetchPage()
    ThreadStats.update postCount, fileCount, ipCount
    $.on d, 'ThreadUpdate', ThreadStats.onUpdate

  onUpdate: (e) ->
    return if e.detail[404]
    {postCount, fileCount, ipCount, newPosts} = e.detail
    ThreadStats.update postCount, fileCount, ipCount
    return unless Conf["Page Count in Stats"]
    if newPosts.length
      ThreadStats.lastPost = g.posts[newPosts[newPosts.length - 1]].info.date
    if ThreadStats.lastPost > ThreadStats.lastPageUpdate and ThreadStats.pageCountEl?.textContent isnt '1'
      ThreadStats.fetchPage()

  update: (postCount, fileCount, ipCount) ->
    {thread, postCountEl, fileCountEl, ipCountEl} = ThreadStats
    postCountEl.textContent = postCount
    fileCountEl.textContent = fileCount
    ipCountEl.textContent   = if ipCount? then ipCount else '?'
    (if thread.postLimit and !thread.isSticky then $.addClass else $.rmClass) postCountEl, 'warning'
    (if thread.fileLimit and !thread.isSticky then $.addClass else $.rmClass) fileCountEl, 'warning'

  fetchPage: ->
    return if !Conf["Page Count in Stats"]
    clearTimeout ThreadStats.timeout
    if ThreadStats.thread.isDead
      ThreadStats.pageCountEl.textContent = 'Dead'
      $.addClass ThreadStats.pageCountEl, 'warning'
      return
    ThreadStats.timeout = setTimeout ThreadStats.fetchPage, 2 * $.MINUTE
    $.ajax "//a.4cdn.org/#{ThreadStats.thread.board}/threads.json", onload: ThreadStats.onThreadsLoad,
      whenModified: true

  onThreadsLoad: ->
    return unless Conf["Page Count in Stats"] and @status is 200
    for page in @response
      for thread in page.threads when thread.no is ThreadStats.thread.ID
        ThreadStats.pageCountEl.textContent = page.page
        (if page.page is @response.length then $.addClass else $.rmClass) ThreadStats.pageCountEl, 'warning'
        # Thread data may be stale (modification date given < time of last post). If so, try again on next thread update.
        ThreadStats.lastPageUpdate = new Date thread.last_modified * 1000
        return
