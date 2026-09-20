# 用真的 key 試跑 jev

框架已完成（見 `logs/20260920-scaffold.md`），缺的是真實環境驗證。


## 步驟

 1. `npm run build`，Chrome 載入未封裝項目指向 `web/static`
 2. 先維持 `provider: mock` 開 FB，確認貼文抓得到、badge 出得來
    ( FB 改版時最先壞的是 `lib/post.ls` 的 selectors )
 3. popup 填 API key、provider 切 `jev`，再看一輪


## 已知限制

畫面上看得到的「贊助」標示抓不到。FB 的 `data-ad-rendering-role="meta"` 區只有連結預覽的
網域, 而且是混淆過的字串 ( `tin41sipSp.com` 這種 ), 「贊助」兩字不在任何抓得到的節點裡,
也不是用 CSS 隱藏的假字元 —— 試過還原可見文字, 沒有用。目前不傳 sponsored 欄位給模型,
是不是廣告完全交給內文判斷。要救的話得另外找訊號 ( CTA 按鈕、l.facebook.com 連結 )。


## 待確認

 - `state` 傳 object 時模型怎麼讀欄位，是否該改成整理好的純文字
 - 三題一次問的成本與延遲，對照分開問是否划算（`usage` 有回 token 數，可從 console 觀察）
 - `threshold` 預設 0.6 是否合適；noul 在 0.5 附近代表模型真的不確定，
   門檻訂太低會讓一般貼文也標紅
 - 網軍那題只看單則貼文的文字，可能不夠 —— 粉專名稱、成立時間、追蹤數才是訊號，
   但那些要另外抓。先看單文字版本的實際表現再決定要不要擴 `state`
