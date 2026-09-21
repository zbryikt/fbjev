# 從 FB 動態牆的 DOM 抽出一則貼文。
#
# FB 的 class name 是編譯產生的亂碼, 每次改版都會變, 所以一律走 data-* 與 role 這類語意屬性。
# 主 feed 目前沒有 role="article" ( 那是留言與其他版型在用的 ), 貼文單元是虛擬列表的
# div[data-virtualized], 內部每個區塊掛 data-ad-rendering-role。這組屬性一般貼文也有,
# 不是只有廣告才掛。選擇器全集中在這裡, FB 改版時只要改這一塊。
post = {}

post.selectors =
  message: '[data-ad-preview="message"], [data-ad-rendering-role="story_message"]'
  unit: 'div[data-virtualized], [role="article"]'
  author: '[data-ad-rendering-role="profile_name"]'
  meta: '[data-ad-rendering-role="meta"]'
  block: 'div[dir="auto"]'
  permalink: '[data-ad-rendering-role="meta"] a[href], a[href*="/posts/"], a[href*="/permalink/"], a[href*="story_fbid"], a[href*="/share/"]'

# 展開按鈕的文字。留著會讓極短的貼文剛好跨過長度門檻, 也會讓模型把它當成內文的一部分。
post.tailWords = <[查看更多 顯示更多 See\ more See\ More]>

# 作者列出現「追蹤」= 這是 FB 推薦的、你沒追蹤的來源
post.suggestWords = <[追蹤 Follow]>

# 沒有 sponsored 欄位是刻意的。畫面上看得到「贊助」, 但它不在任何抓得到的節點裡
# ( meta 區只有連結預覽的網域, 且是混淆過的字串 ), 而傳一個恆為 false 的旗標給模型,
# 等於告訴它「這不是廣告」—— 比不傳更糟。是不是廣告交給模型從內文判斷。

# 有 message 錨點時直接用它; 沒有 ( 其他版型 ) 才退回掃 div[dir=auto] 取最內層,
# 因為 FB 會把同一段文字包好幾層, 不濾掉會重複。
post.textOf = (el) ->
  msg = el.querySelector post.selectors.message
  if msg => return post.trimTail((msg.textContent or '').trim!).slice 0, 2000
  blocks = Array.from(el.querySelectorAll(post.selectors.block))
  leaves = blocks.filter (b) -> not blocks.some (o) -> o != b and b.contains o
  texts = leaves.map (b) -> (b.textContent or '').trim!
  texts = texts.filter (t) -> t.length
  texts.join('\n').slice 0, 2000

post.trimTail = (text) ->
  ret = text
  for w in post.tailWords
    if ret.endsWith w => ret = ret.slice 0, ret.length - w.length
  ret.replace(/[…\s.]+$/, '').trim!

# 推薦內容是網軍與內容農場最主要的投遞管道 —— 追蹤中的朋友不會是網軍。
# 所以「這則是推薦來的」本身就是訊號, 要讓模型知道。
post.isSuggested = (el) ->
  nodes = Array.from el.querySelectorAll('a[role="link"], div[role="button"]')
  nodes.some (n) -> post.suggestWords.indexOf((n.textContent or '').trim!) >= 0

post.authorOf = (el) ->
  node = el.querySelector(post.selectors.author) or el.querySelector('h2 a, h3 a, h4 a, strong a')
  if node => (node.textContent or '').trim!.slice 0, 100 else ''

post.urlOf = (el) ->
  node = el.querySelector post.selectors.permalink
  if node => node.href else ''

# djb2。只用來去重與當快取 key, 不需要抗碰撞強度。
post.hash = (str) ->
  h = 5381
  for i from 0 til str.length
    h = (((h .<<. 5) + h) + str.charCodeAt(i)) .|. 0
  (h .>>>. 0).toString 36

post.fingerprint = (el) ->
  post.hash "#{post.authorOf el} #{post.textOf(el).slice 0, 400}"

post.extract = (el) ->
  text: post.textOf el
  author: post.authorOf el
  url: post.urlOf el
  suggested: post.isSuggested el
  id: post.fingerprint el

# 回傳還需要處理的貼文單元。
#
# 判準是「裝的還是不是同一則」而不是「處理過沒有」: data-virtualized 意思就是虛擬列表,
# 捲過去的節點會被回收裝下一則貼文, 只記 processed 旗標會讓回收後的那則永遠漏掉。
post.collect = (root) ->
  ret = []
  for m in Array.from(root.querySelectorAll(post.selectors.message))
    u = m.closest post.selectors.unit
    continue unless u
    continue if ret.indexOf(u) >= 0
    continue if u.dataset.fbjev and u.dataset.fbjev == post.fingerprint(u)
    ret.push u
  ret

self.fbjev = {} unless self.fbjev?
self.fbjev.post = post
