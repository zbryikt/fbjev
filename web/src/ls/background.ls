# service worker: 判讀請求的唯一出口。
#
# 放在這裡而不是 content script 的理由有三: API key 不進頁面、跨分頁共用同一份快取與
# 佇列、以及 fetch 不受 FB 頁面 CSP 限制。
importScripts '/js/lib/log.js', '/js/lib/config.js', '/js/lib/analyzer.js', '/js/lib/jev.js'

# 同一則貼文在無限捲動中會被重新掛載好幾次, 沒有快取就會重複付費。
# service worker 被回收時快取跟著消失 - 這是加速手段, 不是保證。
cache = new Map!
cacheLimit = 500

queue =
  limit: 3        # FB 一次能捲出十幾則, 不限流會瞬間打爆 API
  active: 0
  items: []

# 維度會增減, 統計欄位跟著 analyzer 走, 不要在這裡再列一次
stats = fbjev.analyzer.zeroStats!

# 抽成具名函式而不是在迴圈裡寫 closure: `item` 是函式作用域變數,
# 下一輪就被覆寫, 留在迴圈裡的 callback 會抓到錯的那一筆。
dispatch = (item) ->
  item.fn!
    .then (v) -> item.res v
    .catch (e) -> item.rej e
    .then ->
      queue.active -= 1
      drain!

drain = ->
  while queue.active < queue.limit and queue.items.length
    item = queue.items.shift!
    queue.active += 1
    dispatch item

push = (fn) ->
  new Promise (res, rej) ->
    queue.items.push {fn: fn, res: res, rej: rej}
    drain!

prune = ->
  while cache.size > cacheLimit
    cache.delete cache.keys!.next!.value

bump = (verdict, cfg) ->
  stats.total += 1
  for d in fbjev.analyzer.dimensions
    if (verdict[d]?score or 0) >= cfg.threshold => stats[d] += 1
  fbjev.config.set {stats: stats}

run = (p, cfg) ->
  hit = cache.get p.id
  return Promise.resolve hit if hit
  task = ->
    # 沒有 key 就退回 mock: 否則每則貼文都是一次 401, 使用者只會看到滿排的驚嘆號。
    # 降級放在這裡而不是 config.get, 設定面板才能忠實顯示使用者自己選的來源。
    if cfg.provider == \jev and cfg.apiKey
      fbjev.jev.analyze p, cfg
    else
      Promise.resolve fbjev.analyzer.mock(p)
  push task
    .then (verdict) ->
      cache.set p.id, verdict
      prune!
      bump verdict, cfg
      verdict

chrome.runtime.onMessage.addListener (msg, sender, send) ->
  if not msg or msg.type != \analyze => return false
  fbjev.config.get!
    .then (cfg) -> run msg.post, cfg
    .then (verdict) -> send {verdict: verdict}
    .catch (e) ->
      fbjev.log.warn 'analyze failed:', e
      send {error: e.message}
  # 非同步回覆, 必須讓 channel 保持開啟
  true

# service worker 重新啟動時把統計接回來, 否則 popup 的數字會歸零
fbjev.config.get!.then (cfg) -> stats <<< (cfg.stats or {})
