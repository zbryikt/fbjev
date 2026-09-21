# typesafe.ai ( jev ) provider。
#
# API: POST https://api.typesafe.ai/v1/systemone  ( docs.typesafe.ai/api )
# 用 noul 問題型別: 一題一個 yes/no 命題, 直接回 0~1 的機率, 不必要求模型吐 JSON
# 再解析 - 三個面向剛好就是三題, 一次請求問完。
jev = {}

jev.timeout = 20000
jev.retryDelay = 1500

# criteria 是選填的, 但寫清楚 true/false 各是什麼比只給一句 instructions 穩得多。
jev.questions =
  ai:
    type: \noul
    instructions: '這則貼文的文字是否由 AI 生成?'
    criteria:
      "true": '措辭工整對稱、套語堆疊、缺乏具體細節與個人經驗, 像模型產出的文章'
      "false": '有具體細節、口語、錯字或個人語氣, 像真人隨手寫的'
  ad:
    type: \noul
    instructions: '這則貼文是否為廣告或商業推銷?'
    criteria:
      "true": '推銷商品或服務、導購連結、優惠價格、要求私訊下單'
      "false": '沒有商業意圖的一般分享'
  troll:
    type: \noul
    instructions: '這則貼文是否為網軍或內容農場式的操作內容?'
    criteria:
      "true": '匿名可拋棄式粉專發出的聳動標題、情緒動員、要求轉發、與事實無關的垃圾內容。
        from_suggested_page 為 true ( 使用者沒追蹤、由 FB 推薦而來 ) 時要提高懷疑,
        帳號名稱像隨機產生 ( 英文加數字 ) 也是訊號'
      "false": '一般使用者的真實發文, 即使立場鮮明'
  hate:
    type: \noul
    instructions: '這則貼文是否在煽動仇恨或對立?'
    criteria:
      "true": '針對族群、身分、職業或立場的敵意言論、貶抑稱呼、鼓動攻擊或排除'
      "false": '批評事情本身、就事論事的爭論, 即使語氣強烈'
  noob:
    type: \noul
    instructions: '發文者看起來是否為網路小白?'
    criteria:
      "true": '搞不清楚狀況、誤解語境、答非所問、把公開版面當私訊用、明顯不熟悉網路慣例'
      "false": '清楚自己在說什麼、語境掌握正常的發文'

jev.payload = (p, cfg) ->
  state:
    author: p.author
    text: p.text
    url: p.url
    "from_suggested_page": p.suggested
  model: cfg.model
  questions: jev.questions

jev.parse = (json, id) ->
  analyzer = self.fbjev.analyzer
  ret = analyzer.empty id
  ret.provider = \jev
  ret.model = json?model
  ret.usage = json?usage
  answers = json?answers or {}
  for d in analyzer.dimensions
    a = answers[d]
    continue unless a?
    ret[d] =
      score: Math.max(0, Math.min(1, +(a.noul or 0)))
      # noul 不回理由, 留空讓 UI 退回顯示分數
      reason: ''
  ret

request = (p, cfg) ->
  ctrl = new AbortController!
  timer = setTimeout (-> ctrl.abort!), jev.timeout
  opt =
    method: \POST
    signal: ctrl.signal
    headers:
      "Content-Type": 'application/json'
      "Authorization": "Bearer #{cfg.apiKey}"
    body: JSON.stringify jev.payload(p, cfg)
  fetch cfg.endpoint, opt
    .then (res) ->
      clearTimeout timer
      if res.ok => return res.json!
      e = new Error "jev #{res.status} #{res.statusText}"
      e.status = res.status
      throw e
    .catch (e) ->
      clearTimeout timer
      throw e

# 429 / 529 是文件明列的暫時性狀態, 退避一次就好: 使用者已經捲過去了,
# 排隊重試到天荒地老只會讓佇列塞住後面真的看得到的貼文。
jev.analyze = (p, cfg) ->
  request p, cfg
    .catch (e) ->
      if e.status not in [429, 529] => throw e
      new Promise (res, rej) ->
        setTimeout (-> request(p, cfg).then res, rej), jev.retryDelay
    .then (json) -> jev.parse json, p.id

self.fbjev = {} unless self.fbjev?
self.fbjev.jev = jev
