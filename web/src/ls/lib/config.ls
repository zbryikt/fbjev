# 共用設定層 - content script / service worker / popup 三邊都載入這支。
# 一律存在 storage.local: MV3 的 service worker 隨時會被回收, 記憶體裡的設定留不住。
config = {}

config.defaults =
  enabled: true
  provider: \mock                                   # mock | jev
  endpoint: 'https://api.typesafe.ai/v1/systemone'
  model: 'jev-latest'                               # 別名, 會跟著新版走; 要固定就寫 jev-1.13.0
  apiKey: ''
  threshold: 0.5                                    # 超過此分數才視為命中
  badge: true                                       # 是否在貼文上顯示標記
  collapse: true                                    # 命中的貼文淡化並收合成一行

config.get = ->
  new Promise (res, rej) ->
    chrome.storage.local.get null, (v) ->
      if chrome.runtime.lastError => return rej new Error(chrome.runtime.lastError.message)
      res ({} <<< config.defaults <<< (v or {}))

config.set = (kv) ->
  new Promise (res, rej) ->
    chrome.storage.local.set kv, ->
      if chrome.runtime.lastError => return rej new Error(chrome.runtime.lastError.message)
      res kv

config.onchange = (cb) ->
  chrome.storage.onChanged.addListener (changes, area) ->
    if area == \local => cb changes

self.fbjev = {} unless self.fbjev?
self.fbjev.config = config
