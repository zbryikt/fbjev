# 設定面板。欄位改動即存 - 這裡沒有「取消」的語意, 多一顆儲存鍵只是多一種忘記按的方式。
fields =
  enabled: \checked
  badge: \checked
  collapse: \checked
  provider: \value
  endpoint: \value
  apiKey: \value
  model: \value
  threshold: \number

el = (id) -> document.getElementById id

msg = (text) ->
  node = el \msg
  node.textContent = text
  if text => setTimeout (-> node.textContent = ''), 2000

fill = (cfg) ->
  for name, kind of fields
    node = el name
    continue unless node
    switch kind
    | \checked => node.checked = !!cfg[name]
    | \number  => node.value = cfg[name]
    | _        => node.value = cfg[name] or ''
  el(\thval).textContent = cfg.threshold
  stats = cfg.stats or {}
  for d in ['total'].concat(fbjev.analyzer.dimensions)
    node = el "st-#{d}"
    if node => node.textContent = stats[d] or 0

collect = ->
  ret = {}
  for name, kind of fields
    node = el name
    continue unless node
    ret[name] = switch kind
    | \checked => node.checked
    | \number  => +node.value
    | _        => node.value
  ret

save = ->
  cfg = collect!
  el(\thval).textContent = cfg.threshold
  fbjev.config.set cfg
    .then -> msg '已儲存'
    .catch (e) -> msg "儲存失敗: #{e.message}"

bind = ->
  for name of fields
    node = el name
    continue unless node
    node.addEventListener \change, -> save!
  el(\threshold).addEventListener \input, -> el(\thval).textContent = el(\threshold).value
  el(\reset).addEventListener \click, ->
    fbjev.config.set {stats: fbjev.analyzer.zeroStats!}
      .then -> fbjev.config.get!
      .then (cfg) ->
        fill cfg
        msg '統計已清除'

fbjev.config.get!
  .then (cfg) ->
    fill cfg
    bind!
  .catch (e) -> msg "讀取設定失敗: #{e.message}"
