# 動態牆觀察器: 找出新載入的貼文 -> 進入視窗才送判讀 -> 回填標記。
#
# 兩層節流是刻意的。MutationObserver 負責「有沒有新東西」, 捲動時一次會爆出上百筆,
# 所以合併成定時掃描; IntersectionObserver 負責「使用者真的看到了嗎」, 沒看到的貼文
# 不送出去, 這是省 API 呼叫最有效的一刀。
watcher = (opt = {}) ->
  @ <<<
    cfg: null
    timer: null
    dead: false
    delay: 300
    minlen: 20        # 短於此長度多半是純圖片/影片貼文, 沒有文字可判讀
  @ <<< opt
  @init!
  @

watcher.prototype = Object.create(Object.prototype) <<<
  constructor: watcher

  init: ->
    @io = new IntersectionObserver ((es) ~> @onview es), {threshold: 0.2}
    @mo = new MutationObserver ~> @schedule!
    @mo.observe document.body, {childList: true, subtree: true}
    @schedule!

  destroy: ->
    @mo.disconnect!
    @io.disconnect!
    if @timer => clearTimeout @timer

  schedule: ->
    return if @timer or @dead
    @timer = setTimeout (~>
      @timer = null
      @scan!
    ), @delay

  scan: ->
    return unless @cfg and @cfg.enabled
    # 只掛觀察, 不在這裡標記: 標記等於宣告「這則的結論是什麼」, 而此刻還沒抽過內容。
    # FB 先畫骨架再填內容, 太早標記會讓填進來的那則永遠被跳過。
    for el in fbjev.post.collect(document.body)
      @io.observe el

  onview: (entries) ->
    for e in entries when e.isIntersecting
      @io.unobserve e.target
      @analyze e.target

  # 擴充功能一重新載入, 舊分頁的 content script 就變成孤兒。sendMessage 在這個狀態
  # 是同步 throw 而不是回一個 rejected promise, 所以 .catch 接不到 —— 必須包在這裡,
  # 否則每則進入視窗的貼文都會丟一個 uncaught error, 標記也就永遠停在 pending。
  send: (p) ->
    try
      return chrome.runtime.sendMessage {type: \analyze, post: p}
    catch e
      @invalidate!
      Promise.reject e

  # 這個狀態救不回來 ( runtime 已經不在了 ), 停掉觀察免得每則貼文再炸一次
  invalidate: ->
    return if @dead
    @dead = true
    @destroy!
    fbjev.log.warn '擴充功能已重新載入, 請重整此分頁後繼續'

  analyze: (el) ->
    return unless @cfg and @cfg.enabled
    return if @dead
    p = fbjev.post.extract el
    # 標記一律寫指紋, 純圖片貼文也是: collect 比對的是指紋, 寫別的字串會讓它每輪重抽
    el.dataset.fbjev = p.id
    return if p.text.length < @minlen
    if @cfg.badge => fbjev.badge.pending el
    @send p
      .then (res) ~>
        if not res or res.error
          fbjev.badge.error el, res?error
          return
        if @cfg.badge => fbjev.badge.render el, res.verdict, @cfg
      .catch (e) ~>
        msg = e?message or ''
        if /context invalidated|Receiving end does not exist/.test msg => @invalidate!
        fbjev.badge.error el, msg

fbjev.config.get!
  .then (cfg) ->
    w = new watcher {cfg: cfg}
    # 設定改了就換掉手上這份, 不必重載頁面
    fbjev.config.onchange -> fbjev.config.get!.then (c) -> w.cfg = c
  .catch (e) -> fbjev.log.error 'init failed:', e
