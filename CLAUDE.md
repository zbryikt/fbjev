# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.


## 專案目標

Chrome extension ( MV3 )：即時判讀 Facebook 動態牆上剛載入的貼文。五個維度：
AI 生成、廣告、網軍、煽動/仇恨、網路小白。判讀交給 typesafe.ai 的 **jev** 模型。
命中門檻（預設 0.5）以上的貼文會淡化並收合成一行，點標記可展開。

維度只在 `analyzer.dimensions` 與 `jev.questions` 兩處定義，badge、統計、background 都跟著跑，
加一個維度改這兩支加 popup.pug 的統計列即可。

原始構想見 `context/project/initiative/index.md`。


## 指令

    npm run build        # 單次建置 web/src -> web/static
    npm start            # 同上並 watch ( @zbryikt/template dev server, 不會自動開瀏覽器 )

載入 extension：Chrome → `chrome://extensions` → 開發人員模式 → 載入未封裝項目 → 選 **`web/static`**。
改完程式跑 build 後，在擴充功能頁按重新載入；改到 content script 要一併重整 FB 分頁。

`web/static`、`web/.view`、`web/.bundle-dep` 全是建置產物，已列入 `.gitignore`，可隨時整個刪掉重建。


## 架構

三個執行環境，各自獨立載入 `js/lib/*.js`，共用全域命名空間 `fbjev`
（LiveScript 以 `bare: true` 編譯，檔案頂層即全域，沒有 module 系統）：

 - **content script** (`content.ls`)：`MutationObserver` 找新掛上的貼文 → `IntersectionObserver`
   過濾成「使用者真的看到的」才送出。兩層節流是省 API 呼叫的關鍵，動它之前先想清楚。
 - **service worker** (`background.ls`)：判讀請求的唯一出口。持有 API key、指紋快取與併發佇列
   ( 上限 3 )。放這裡的理由是 key 不進頁面、跨分頁共用快取、fetch 不受 FB 的 CSP 限制。
 - **popup** (`popup.ls` + `popup.pug`)：設定與統計，欄位改動即存。

`lib/` 下的共用模組：`log`（統一 `[fbjev]` 前綴）、`config`（storage.local 封裝）、`post`（DOM 抽取，FB 選擇器全集中在此）、
`analyzer`（維度定義 + 結果格式 + mock heuristic provider）、`jev`（typesafe.ai client）、`badge`（貼文上的標記）。

資料流：`post.extract` 產出 `{id, author, text, url}`（`id` 是作者+內文的 djb2 指紋，用於去重與快取）
→ `sendMessage` → background 依 `provider` 選 `jev` 或 `mock` → verdict 每個維度一組
`{score 0~1, reason}` → `badge.render` 依 `threshold` 標紅，命中就替貼文加上 `.fbjev-folded`。

沒有 `sponsored` 欄位是刻意的：畫面上的「贊助」字樣抓不到（`meta` 區只有混淆過的網域字串），
傳一個恆為 false 的旗標等於告訴模型「這不是廣告」，比不傳更糟。詳見 `tasks/todo/jev-trial.md`。

**content script 是可以被判死的**：擴充功能一重載，舊分頁的 content script 就變成孤兒，
`chrome.runtime.sendMessage` 會**同步 throw**（不是回 rejected promise），`.catch` 接不到。
`watcher.send` 包了 try/catch，`invalidate` 會停掉觀察並要求重整分頁 —— 沒有這層，
每則進入視窗的貼文都會丟一個 uncaught error，標記永遠停在 `⋯`。

**mock provider 不是玩具**：沒有 API key 時整條管線照跑，可以單獨驗證 DOM 抽取與 UI。
改 FB 選擇器或 badge 時用它，不要為了看畫面去打 API。


## typesafe.ai / jev API

`POST https://api.typesafe.ai/v1/systemone`，`Authorization: Bearer <key>`，文件 https://docs.typesafe.ai/api

用 `noul` 問題型別：一題一個 yes/no 命題，直接回 0~1 機率，不必叫模型吐 JSON 再解析。
五個面向 = 五題，一次請求問完（約 800 input tokens）。回應是 `{model, answers: {<id>: {noul}}, usage}`。
model 預設 `jev-latest`（別名，會跟著新版走；要固定寫 `jev-1.13.0`）。
429 / 529 是文件明列的暫時狀態，client 退避重試一次就放棄。


## 慣例

`context/shared/` 是團隊開發慣例的 symlink（→ `~/.context/@plotdb/guides/src`），動手前依主題查閱：

 - `1.context-project-guide.md` — `context/project/` 下 initiative / tasks / logs / ref 的分工
 - `2.fedev.md` — 前端環境、Pug `+css` / `+script` mixin、fedep
 - `3.version-control.md` — CHANGELOG 格式、commit 流程、`a.c.p` / `bv` 縮寫
 - `9.lsc-coding-guide.md` — **LiveScript 的陷阱清單，寫 .ls 前必讀**

本專案踩過的兩個：位元運算要寫 `.<<.` / `.|.`（`<<` 是函式合成，不會報錯）；
迴圈內註冊 callback 必須把 body 抽成具名函式，`do (x) ->` 編譯出來不會把 `x` 傳進去。

其餘重點：兩空白縮排、`{` 不單獨一行、**避免 async/await 改用 Promise**、
constructor pattern + `Object.create` 重建 prototype、kebab-case 命名（但原生 API 沿用 camelCase）。
