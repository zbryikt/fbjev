# CHANGELOG

## master

 - features:
   - Chrome extension ( MV3 ) 框架: content script / service worker / popup 三段
   - FB 動態牆貼文抽取, 以 `data-ad-rendering-role` 與 `data-virtualized` 為錨點
   - typesafe.ai ( jev ) provider, 以 noul 問題型別一次問完五題
   - 本地 heuristic mock provider, 沒有 API key 時整條管線仍可跑
   - 五個判讀維度: AI 生成 / 廣告 / 網軍 / 煽動仇恨 / 網路小白
   - 命中門檻以上的貼文淡化並收合成一行, 點標記可展開
   - popup 設定面板與本機統計, 欄位改動即存
   - 統一的 `[fbjev]` log 前綴
 - tweaks:
   - MIT license
   - 英文 README
   - `CLAUDE.md` 移出版控 ( 內容指向內部 guides, 對 public repo 的讀者沒有意義 )
