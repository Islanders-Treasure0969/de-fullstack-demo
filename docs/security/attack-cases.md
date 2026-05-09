# 攻撃事例集

> 記事冒頭の動機付けと、各章「なぜこの対策が必要か」の事例引用に使う。
> 凡例：要確認 = 一次資料で日付・CVE・規模を再点検すべき箇所。

## なぜ事例から始めるか

「セキュリティ対策はコストである」という反応を防ぐには、**実際に起きた攻撃が、自分のリポでも起こり得たことを具体的に見せる**のが最短。本記事では各レイヤー解説の冒頭に「このレイヤーが破られた事例」を配置する。

---

## 事例マトリクス（一覧）

| 事例 | 年 | 攻撃手口 | 主に破られたレイヤー | 関連 Scorecard / OWASP |
|---|---|---|---|---|
| xz-utils backdoor | 2024 | 長期的なメンテナソーシャルエンジニアリング | メンテナアイデンティティ / 信頼チェーン | Code-Review, Maintained / CICD-SEC-1 |
| tj-actions/changed-files | 2025 | 人気 Action のリポ侵害、tag 改ざん | 3rd party Action 信頼 | Pinned-Dependencies / CICD-SEC-3, 8 |
| Codecov bash uploader | 2021 | CI スクリプト改ざんによる顧客 secret 窃取 | 3rd party CI 統合 | / CICD-SEC-3, 8 |
| SolarWinds Orion | 2020 | ビルドシステム侵害、署名済みビルドへ悪性 DLL 注入 | ビルドパイプライン / artifact integrity | Signed-Releases / CICD-SEC-4, 9 |
| PyTorch torchtriton | 2022 | Dependency confusion（内部名と同名のパッケージを PyPI に登録） | 依存解決 | / CICD-SEC-3 |
| node-ipc protestware | 2022 | メンテナ自身による wiper 同梱 | 依存先メンテナ信頼 | / CICD-SEC-3 |
| Ledger Connect Kit | 2023 | npm メンテナ NPM トークン漏洩経由 | 依存配布チェーン | / CICD-SEC-3, 6 |
| ultralytics PyPI 侵害 | 2024 | GitHub Actions cache 経由の token 窃取 | CI runner / トークン管理 | Token-Permissions / CICD-SEC-4, 5, 6 |

> 上記日付・規模は要確認（執筆時に一次資料で再点検）。

---

## ケース 1: xz-utils backdoor (CVE-2024-3094)

**起きたこと（要確認）**
- 2024 年 3 月、Linux 圏で広く使われている圧縮ライブラリ `xz-utils` の 5.6.0/5.6.1 リリースに、SSH 経由のリモートコード実行を可能にするバックドアが混入していた
- 攻撃者は約 2 年かけてメンテナとして信頼を獲得（"Jia Tan" アカウント）→ 単独メンテナ Lasse Collin の負担を軽減する形で commit 権を得る → リリース直前に難読化されたペイロードを test fixture として注入
- Andres Freund（Microsoft）がパフォーマンス調査で偶然発見、stable リリース直前に止まった

**破られたレイヤー**
- メンテナアイデンティティ（社会的信頼）
- 単独メンテナのバス係数 1 状態
- バイナリテストフィクスチャの暗黙的信頼

**学び**
- single-maintainer プロジェクトの脆弱性。Scorecard `Contributors` チェックの示唆と直結
- バイナリ test fixture のレビュー困難性 → Scorecard `Binary-Artifacts`
- 社会的攻撃には技術的対策だけでは限界、コミュニティ層での観測（"who is this new maintainer"）が必要

**参照**
- <https://research.swtch.com/xz-timeline>
- <https://www.openwall.com/lists/oss-security/2024/03/29/4>

---

## ケース 2: tj-actions/changed-files (2025 年 3 月、要確認)

**起きたこと**
- GitHub Marketplace で広く使われていた Action `tj-actions/changed-files` のリポが侵害され、複数の tag が改ざんされて secret 窃取コードが仕込まれた
- tag を fix-version で参照していた多数のリポで CI ログから secret が漏洩
- full SHA で pin していた利用者は被害を免れた

**破られたレイヤー**
- 3rd party GitHub Action の信頼（CICD-SEC-8）
- tag は mutable であるという前提の理解不足

**学び**
- **GitHub Actions は full SHA でピン留め**が事実上必須（Scorecard `Pinned-Dependencies`）
- Renovate の `pinDigests: true` を使えば自動的に達成
- CI workflow は `permissions:` を最小化、secret は echo 時にマスクされても CI ログから抜ける手法が存在

**参照**
- <https://www.stepsecurity.io/blog/harden-runner-detection-tj-actions-changed-files-action-is-compromised>（要確認）

---

## ケース 3: Codecov bash uploader (2021 年 4 月)

**起きたこと**
- Codecov の bash uploader (`codecov.io/bash`) が約 2 ヶ月にわたり改ざんされた状態で配布
- カスタマーの CI 環境変数（AWS、GitHub、リポジトリ secret）を攻撃者の URL に送信
- 影響：HashiCorp、Twilio、Rapid7 など多数

**破られたレイヤー**
- 外部 CI サービスの暗黙的信頼（curl | bash の典型）
- artifact integrity（CICD-SEC-9）

**学び**
- `curl https://... | bash` を CI で使うときはチェックサム検証必須
- 3rd party サービスへ提供する secret は最小スコープ＋短寿命に
- CICD-SEC-8（Ungoverned 3rd Party）の代表例として引用しやすい

**参照**
- <https://about.codecov.io/security-update/>

---

## ケース 4: SolarWinds Orion (2020 年 12 月)

**起きたこと**
- SolarWinds 社のビルドシステムが侵害され、Orion ソフトウェアの**正規署名済み更新パッケージ**にバックドア（SUNBURST）が混入
- 影響：米政府機関、Microsoft、FireEye 等を含む数千組織
- これが SLSA (Supply-chain Levels for Software Artifacts) 策定の直接的動機の一つ

**破られたレイヤー**
- ビルドパイプライン本体（CICD-SEC-4 PPE の極端な例）
- ビルドの再現性・隔離（SLSA L3 が想定する脅威）

**学び**
- 「署名されている」は「ビルドが正しい」を保証しない
- ビルド環境の隔離（ephemeral runner、再現可能ビルド）と provenance（誰が・どこで・どう作ったか）の併用が必要
- SLSA L3 / NIST SSDF PS.2 が直接対応

**参照**
- <https://slsa.dev/spec/v1.0/threats>
- <https://www.cisa.gov/news-events/cybersecurity-advisories/aa20-352a>

---

## ケース 5: PyTorch torchtriton dependency confusion (2022 年 12 月)

**起きたこと**
- PyTorch nightly に内部依存として `torchtriton` が含まれていた
- 攻撃者が PyPI に同名の悪意あるパッケージを登録 → pip の依存解決が PyPI を優先することで悪意版がインストールされる
- 影響期間中の PyTorch nightly インストール環境から `~/.ssh`、HOME 配下、ホスト名等が攻撃者サーバへ送信

**破られたレイヤー**
- パッケージ依存解決の前提（CICD-SEC-3）

**学び**
- 内部レジストリと公開レジストリの**名前空間衝突**を前提に設計する
- 公開 mirror / scoped package / 内部レジストリ優先解決
- requirements の `--index-url` 制御、`--extra-index-url` の罠を避ける

**参照**
- <https://pytorch.org/blog/compromised-nightly-dependency/>

---

## ケース 6: node-ipc protestware (2022 年 3 月)

**起きたこと**
- 人気 npm パッケージ `node-ipc` のメンテナが、ロシア／ベラルーシの IP から動作した場合に**ファイルを上書きする**コードを混入
- 抗議目的だが、依存先のすべての利用者に影響（一部 Vue ビルドが影響）

**破られたレイヤー**
- 依存メンテナの善意前提（CICD-SEC-3）

**学び**
- メンテナの善意は前提にできない（protestware / disgruntlement / takeover いずれも）
- バージョン pin と SBOM レビューが必要、自動更新の盲信は危険
- Renovate の `minimumReleaseAge` を patch/minor にも適用する選択肢

**参照**
- <https://snyk.io/blog/peacenotwar-malicious-npm-node-ipc-package-vulnerability/>

---

## ケース 7: Ledger Connect Kit (2023 年 12 月)

**起きたこと**
- 暗号資産ハードウェアウォレット Ledger 提供の `@ledgerhq/connect-kit` の元従業員 NPM トークンがフィッシングで奪われ、悪意版が公開
- DeFi プロトコル多数のフロントエンドが影響、約 60 万ドルの被害（要確認）

**破られたレイヤー**
- 配布チャネルの認証（CICD-SEC-6）
- 元従業員アカウントの棚卸し（CICD-SEC-2）

**学び**
- npm publish 権限を持つアカウントには 2FA 必須（npm 側で 2024 から強制）
- 元従業員のアクセス棚卸し
- フロントエンド npm 依存も SRI（Subresource Integrity）の検討

**参照**
- <https://www.ledger.com/blog/a-letter-from-ledgers-ceo-pascal-gauthier-regarding-ledger-connect-kit-exploit>

---

## ケース 8: ultralytics PyPI 侵害 (2024 年 12 月、要確認)

**起きたこと**
- 人気の物体検出ライブラリ `ultralytics` の PyPI パッケージが侵害
- 入り口は GitHub Actions の cache poisoning と branch name injection を組み合わせ → ビルドトークン窃取 → PyPI に悪意版 push

**破られたレイヤー**
- GitHub Actions の最小権限不徹底（CICD-SEC-5）
- ブランチ名等 untrusted input の `${{ }}` 展開（CICD-SEC-4）

**学び**
- workflow `permissions:` 最小化（Scorecard `Token-Permissions`）
- `${{ github.head_ref }}` 等をシェルへ素のまま渡さず `env:` 経由
- `pull_request_target` での checkout 禁止（Scorecard `Dangerous-Workflow`）

**参照**
- <https://www.bleepingcomputer.com/news/security/ultralytics-ai-model-hijacked-to-infect-thousands-with-cryptominer/>（要確認）

---

## 章への割り当て（記事執筆時マッピング）

| 章 | 冒頭で使う事例 |
|---|---|
| 1. 導入 | xz-utils + tj-actions（最近性 + 衝撃度） |
| 5. Branch Protection | xz（弱いコードレビュー文化） |
| 6. CI/CD Hardening | tj-actions, ultralytics |
| 7. Dependencies | torchtriton, node-ipc, Ledger |
| 8. SAST/SCA | （Scorecard Vulnerabilities の説明と紐付け） |
| 9. Build & Artifact | SolarWinds（SLSA の動機として） |
| 11. Disclosure | xz（OSS 緊急対応の最近の事例として） |
