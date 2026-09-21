# 判讀結果的格式與本地 heuristic provider。
#
# mock provider 存在的理由: 沒有 API key 時整條管線 ( 觀察 -> 佇列 -> 標記 ) 仍然跑得動,
# 可以單獨驗證 DOM 抽取與 UI, 不必每次都打 API。判準本身刻意寫得粗糙, 真正的判讀交給模型。
analyzer = {}

analyzer.dimensions = <[ai ad troll hate noob]>

# 標記上用短名 ( 五個 chip 並排, 長名會擠爆 ), tooltip 用全名
analyzer.labels =
  ai: 'AI'
  ad: '廣告'
  troll: '網軍'
  hate: '仇恨'
  noob: '小白'

analyzer.names =
  ai: 'AI 生成'
  ad: '廣告推銷'
  troll: '網軍操作'
  hate: '煽動 / 仇恨內容'
  noob: '網路小白'

analyzer.words =
  ai: <[總的來說 值得注意的是 在當今 讓我們一起 綜上所述 首先 其次 最後 不僅 而且 隨著科技 深入探討]>
  ad: <[限時 優惠 立即購買 私訊 免費領取 團購 下單 連結在留言 原價 只要 加LINE 點我]>
  troll: <[震驚 快轉發 不轉不是 你還敢 覺醒吧 別再被騙 真相曝光 出事了 崩潰 唯一解方]>
  hate: <[滾出去 廢物 垃圾人 去死 該死 死好 智障 腦殘 蟑螂 畜生 不是人 通通抓去]>
  noob: <[求解 有人可以教我嗎 我不懂 first 卡位 沙發 看不懂在說什麼 到底在講什麼 是在哈囉]>

analyzer.empty = (id) ->
  ret = {id: id, provider: 'none', at: Date.now!}
  for d in analyzer.dimensions => ret[d] = {score: 0, reason: ''}
  ret

analyzer.zeroStats = ->
  ret = {total: 0}
  for d in analyzer.dimensions => ret[d] = 0
  ret

hit = (text, words) -> words.filter (w) -> text.indexOf(w) >= 0

analyzer.mock = (p) ->
  text = p.text or ''
  ret = {id: p.id, provider: 'mock', at: Date.now!}
  for d in analyzer.dimensions
    ws = hit text, analyzer.words[d]
    ret[d] =
      score: Math.min(1, ws.length * 0.3)
      reason: if ws.length => "命中字詞: #{ws.join ', '}" else ''

  # 驚嘆號密度是最省事的聳動指標; 短文更明顯, 所以用比例而非絕對數量
  bangs = (text.match(/[!！]/g) or []).length
  if text.length > 0 and bangs / Math.max(text.length / 50, 1) > 2
    ret.troll.score = Math.min(1, ret.troll.score + 0.3)
    ret.troll.reason = ((ret.troll.reason or '') + ' 驚嘆號密集').trim!

  # 追蹤中的朋友不會是網軍; 推薦來的就未必
  if p.suggested
    ret.troll.score = Math.min(1, ret.troll.score + 0.2)
    ret.troll.reason = ((ret.troll.reason or '') + ' 未追蹤的推薦來源').trim!

  ret

self.fbjev = {} unless self.fbjev?
self.fbjev.analyzer = analyzer
