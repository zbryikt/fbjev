# 貼文上的判讀標記, 以及命中後把整張卡片收起來。
#
# 樣式全部前綴 fbjev-, 只加在自己建立的節點上, 對 FB 的節點只加 class 不改結構:
# FB 的 CSS 會不斷改版, 動它的節點或沿用它的 class 遲早會壞。
badge = {}

badge.ensure = (el) ->
  node = el.querySelector ':scope > .fbjev-badge'
  return node if node
  # 貼文單元多半沒有 positioning context, 補一個才能把標記釘在右上角
  if getComputedStyle(el).position == \static => el.style.position = \relative
  node = document.createElement \div
  node.className = 'fbjev-badge'
  # 收合是判斷, 不是結論: 點一下就能看原文。stopPropagation 是必要的,
  # 否則點擊會被 FB 的卡片當成「開啟貼文」。
  node.addEventListener \click, (e) ->
    e.stopPropagation!
    e.preventDefault!
    el.classList.toggle 'fbjev-folded'
  el.appendChild node
  node

badge.pending = (el) ->
  node = badge.ensure el
  node.dataset.state = \pending
  node.textContent = '⋯'
  node

badge.error = (el, msg) ->
  node = badge.ensure el
  node.dataset.state = \error
  node.textContent = '!'
  node.title = msg or '判讀失敗'
  node

badge.render = (el, verdict, cfg) ->
  analyzer = self.fbjev.analyzer
  node = badge.ensure el
  node.dataset.state = \done
  # 判讀來源寫在節點上: 分數是 0 的時候, 這是唯一能分辨「模型說不是」與「根本沒問模型」的線索
  node.dataset.provider = verdict.provider or ''
  node.textContent = ''
  node.title = ''
  hits = []
  for d in analyzer.dimensions
    v = verdict[d] or {score: 0, reason: ''}
    over = v.score >= cfg.threshold
    if over => hits.push "#{analyzer.names[d]} #{Math.round(v.score * 100)}"
    chip = document.createElement \span
    chip.className = 'fbjev-chip'
    chip.dataset.dim = d
    chip.dataset.hit = if over => \1 else \0
    chip.textContent = "#{analyzer.labels[d]} #{Math.round(v.score * 100)}"
    chip.title = v.reason or "#{analyzer.names[d]}: #{Math.round(v.score * 100)} 分"
    node.appendChild chip
  if cfg.collapse and hits.length => badge.fold el, node, hits else badge.unfold el, node
  node

badge.fold = (el, node, hits) ->
  el.classList.add 'fbjev-folded'
  node.title = "#{hits.join ' · '}\n點一下展開"

badge.unfold = (el, node) ->
  el.classList.remove 'fbjev-folded'

self.fbjev = {} unless self.fbjev?
self.fbjev.badge = badge
