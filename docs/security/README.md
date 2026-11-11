# Security Knowledge Base

> 記事「公開リポジトリの多層防御」と Claude プラグイン `secure-repo-toolkit` 共通の素材集。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [layers.md](./layers.md) | 9 レイヤー taxonomy。記事の章立ての背骨、スキル監査項目の母体 |
| [frameworks.md](./frameworks.md) | OpenSSF Scorecard / OWASP CI/CD Top 10 / NIST SSDF / SLSA のマッピング表 |
| [attack-cases.md](./attack-cases.md) | xz / tj-actions / Codecov / SolarWinds 等の事例集 |
| [references.md](./references.md) | 一次資料・公式 docs・主要ツールへのリンク |
| [prior-art.md](./prior-art.md) | 既存 Claude プラグイン・CLI ツールの調査結果 |

## 進行状況

- [x] Phase 1A: フレームワークマッピング（`frameworks.md`）
- [x] Phase 1B: 攻撃事例集（`attack-cases.md`）
- [x] Phase 1C: 参照リスト（`references.md`）
- [x] Phase 1D: 既存ツール調査（`prior-art.md`）
- [x] レイヤー taxonomy（`layers.md`）
- [ ] Phase 2: Scorecard 実走と自リポ評価
- [ ] Phase 3: 記事下書き
- [ ] Phase 4: `secure-repo-toolkit` プラグイン構築（独立リポへ）

## 用法

### 記事執筆時
- `layers.md` → 各章の構成
- `frameworks.md` → 章冒頭に貼るマッピング表
- `attack-cases.md` → 章冒頭の motivation
- `references.md` → 引用 URL の一括管理

### プラグイン構築時
- `layers.md` → audit / scaffold / scorecard コマンドの責務分担
- `frameworks.md` → audit 結果のフレームワーク対応出力
- `prior-art.md` → ラップ対象 CLI（Scorecard / Legitify / harden-runner）

## 残検証事項

`prior-art.md` 末尾の「F. 残検証事項」を参照。プラグイン構築開始前に一括確認する。
