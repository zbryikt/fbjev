# 統一的輸出前綴。三個執行環境的訊息會混在不同的 console 裡 ( 頁面、service worker、popup ),
# 沒有前綴就分不出哪一行是自己的。
log = {}

log.tag = '[fbjev]'

emit = (fn, args) -> fn.apply console, [log.tag].concat(Array.prototype.slice.call args)

log.info = -> emit console.log, arguments
log.warn = -> emit console.warn, arguments
log.error = -> emit console.error, arguments

self.fbjev = {} unless self.fbjev?
self.fbjev.log = log
