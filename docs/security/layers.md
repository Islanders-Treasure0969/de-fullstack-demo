# 多層防御レイヤー taxonomy

> 本記事の背骨となる分類。各レイヤーは独立に評価でき、かつ上位レイヤーが破られても下位で検出・遅延できることを目的とする。
> 記事の章立て、スキルの監査項目、scaffold の生成テンプレート、すべてこの分類を共有する。

## レイヤー一覧

| # | レイヤー | 一行説明 | 主に守る資産 |
|---|---|---|---|
| 1 | Repo Policy | リポジトリの社会契約・ガバナンス基盤 | プロセス信頼 |
| 2 | Branch Protection | デフォルトブランチへのコード注入を物理的にブロック | コード正当性 |
| 3 | CI/CD Hardening | パイプラインを攻撃面として最小化 | CI トークン・成果物 |
| 4 | Identity & Secrets | 人間・サービスアカウント・secret の最小権限化 | 認証情報 |
| 5 | Dependencies | 第三者コードの取り込みを安全にする | 依存ツリー |
| 6 | SAST / SCA / Secret / IaC scan | コード・依存・設定の自動静的検査 | コード・設定 |
| 7 | Build & Artifact | ビルド成果物の改ざん検出を可能にする | 配布物 |
| 8 | Runtime / Container | 実行時の被害最小化 | ランタイム環境 |
| 9 | Disclosure & IR | 脆弱性受領と対応プロセス | 信頼回復速度 |

---

## レイヤー 1: Repo Policy

**目的**：リポの存在意義・連絡窓口・貢献ルールを文書化し、攻撃者が「ここは無人で誰も見ていない」と判断する余地を消す。

**主な脅威**
- 脆弱性報告先が不明で公開 issue 化される
- 外部からの悪意ある PR を受け入れる土壌
- メンテナ不在に乗じたアカウント乗っ取り

**コントロール**
- `SECURITY.md`：private vulnerability reporting + 連絡先 + SLA
- `CODEOWNERS`：パスごとの required reviewer
- `CONTRIBUTING.md`：受入ポリシー（外部 PR を受けるか／受けないか）
- `LICENSE`：明示
- 適切な `README.md`：プロジェクトの状態（Active / Archived / Maintenance Mode）

**フレームワーク対応**

| | |
|---|---|
| Scorecard | Security-Policy / License / Maintained |
| OWASP CI/CD | — |
| SSDF | PO.5, RV.1.1 |

**自リポ実装**：✅ `SECURITY.md` / `CODEOWNERS` / `CONTRIBUTING.md` / `LICENSE` 揃い、外部 PR 不可を明記。

**スキル自動化観点**：scaffold で全テンプレ生成、audit で存在チェック＋私書箱 URL の妥当性検証。

---

## レイヤー 2: Branch Protection

**目的**：デフォルトブランチに対するすべての変更が「レビュー＋ CI 緑」を経ていることを **GitHub 側の仕組みで強制**する。

**主な脅威**
- メンテナ自身のアカウントを奪取された場合の直 push
- レビュー不要設定のままマージ
- force-push による履歴改ざん
- PR 作者がレビューを自己承認

**コントロール**
- 必須レビュー（`required_pull_request_reviews`、最低 1 名）
- CODEOWNERS 必須レビュー（`require_code_owner_reviews`）
- stale review の自動取り消し（`dismiss_stale_reviews`）
- 必須ステータスチェック（`required_status_checks`：CI / SAST / 依存スキャン）
- 線形履歴（`required_linear_history`）
- force-push 禁止（`allows_force_pushes: false`）
- 削除禁止（`allows_deletions: false`）
- 署名コミット必須（`required_signatures`）※運用負荷とのトレードオフ
- admin にも適用するか（`enforce_admins`）

**フレームワーク対応**

| | |
|---|---|
| Scorecard | Branch-Protection, Code-Review |
| OWASP CI/CD | CICD-SEC-1 |
| SSDF | PW.7.1 |

**自リポ実装**：✅ `infra/live/_bootstrap/main.tf` で有効化済み。required checks（`ci / gate`, `codeql / gate`, `trivy / gate`, `gitleaks / gate`）+ CODEOWNERS レビュー必須 + `require_signed_commits = true` + 強制 linear history。`tofu apply` は手動運用（`infra/live/_bootstrap/README.md` 参照）。

**スキル自動化観点**：audit で GitHub API 経由に branch protection 設定を取得→ `terraform/github_branch_protection` 推奨設定との diff を出す。scaffold は IaC ファイルを生成。

---

## レイヤー 3: CI/CD Hardening

**目的**：CI/CD パイプラインを「攻撃面」として捉え、被害範囲・可動権限・実行可能コードの取り込み経路を最小化する。

**主な脅威**（OWASP CI/CD Top 10 の中心）
- Poisoned Pipeline Execution (PPE) — fork PR から悪意コードが CI に流れる
- 過剰な `GITHUB_TOKEN` 権限による secret 持ち出し
- `pull_request_target` での checkout が基本的に危険
- `${{ ... }}` への untrusted input 注入（`github.head_ref` をシェルへ素のまま）
- 3rd party Action の tag 改ざん
- self-hosted runner への足場残留

**コントロール**
- `permissions:` を workflow と job ごとに最小化（`contents: read` 既定）
- 全 `actions/*` を **full SHA でピン留め**
- untrusted input は `env:` で受けてからシェルへ
- `pull_request_target` を避ける、必要時は checkout しない
- `concurrency` で同時実行抑制
- `paths-filter` で必要時のみ起動（攻撃面と費用の両面で有効）
- `step-security/harden-runner` で egress / file / process 監視
- secret は environment scoping、OIDC で短寿命トークン化（AWS / GCP / Azure）
- self-hosted runner は ephemeral、隔離 VPC

**フレームワーク対応**

| | |
|---|---|
| Scorecard | Token-Permissions, Dangerous-Workflow, Pinned-Dependencies |
| OWASP CI/CD | CICD-SEC-1, 4, 5, 7 |
| SSDF | PW.8.* |

**自リポ実装**：✅ 大部分。`auto-merge.yml` の `pull_request_target` 利用は actor 制限あり、ただし将来 checkout 追加時の事故源として削除推奨。

**スキル自動化観点**：audit で workflow YAML を AST 解析（`actionlint` ラップ）、`permissions:` 欠落・`pull_request_target` 検出・SHA 未 pin を一覧化。

---

## レイヤー 4: Identity & Secrets

**目的**：「誰が・何を・どこで使えるか」を **最小・短寿命・可観測** にする。

**主な脅威**
- 長期 PAT のリポ・組織横断的乱用
- 元従業員アカウントの放置
- secret のコミット混入
- フィッシングによるメンテナアカウント奪取
- secret の workflow log 出力

**コントロール**
- GitHub Org/Repo レベルで MFA 強制、SSO 連携
- PAT の代わりに GitHub App / Fine-grained PAT / OIDC
- secret は環境変数として `secrets.*` 経由のみ参照、ログ出力時 `::add-mask::`
- アクセスの定期棚卸し（90 日／180 日）
- リポ側：`.gitignore` で `.env`, `*.pem`, `*.key`, `.aws/`, `.gcp/`
- pre-commit + CI で secret scan（gitleaks / trufflehog）
- GitHub Secret Scanning + Push Protection 有効化
- アプリ側 secret は `pydantic.SecretStr` 等で型安全に隔離

**フレームワーク対応**

| | |
|---|---|
| Scorecard | （Token-Permissions と関連） |
| OWASP CI/CD | CICD-SEC-2, 6 |
| SSDF | PS.1 |

**自リポ実装**：✅ `.gitignore` 充実、pre-commit + CI gitleaks 二段、`SecretStr` 採用。

**スキル自動化観点**：audit で `.gitignore` の必要パターン充足・gitleaks 実行・`secrets.*` 以外の hardcode 検出。

---

## レイヤー 5: Dependencies

**目的**：第三者コードの取り込みを **「いつ・誰の・どのバージョンを・どう検証して」** 取り込むかを制御する。

**主な脅威**
- typosquatting（`colorama` vs `colourama`）
- dependency confusion（内部名と同名の公開パッケージ）
- protestware（メンテナ自身による悪意混入）
- メンテナアカウント乗っ取りによる悪意リリース
- transitive dependency の脆弱性
- tag-based pinning による mutable 参照

**コントロール**
- 自動更新ボット（Renovate / Dependabot）
- vulnerability alerts（patch リリース即適用、`minimumReleaseAge: 0`）
- digest pin（Docker、GitHub Actions）
- lockfile maintenance（週次）
- patch/minor は CI 緑で auto-merge、major は CODEOWNERS 必須
- SCA で既知脆弱性を継続検査（Trivy / Snyk / Mend）
- SBOM 生成して依存ツリー可視化
- 内部レジストリ優先解決（`--index-url` 制御、scoped package）

**フレームワーク対応**

| | |
|---|---|
| Scorecard | Dependency-Update-Tool, Vulnerabilities, Pinned-Dependencies |
| OWASP CI/CD | CICD-SEC-3, 8 |
| SSDF | PW.4 |

**自リポ実装**：✅ Renovate + Dependabot 二段、digest pin、SBOM (CycloneDX/SPDX)、`security-issue.yml` で critical alert 自動 issue 化。

**スキル自動化観点**：audit で renovate/dependabot 設定の有無、`pinDigests` の有効化、Dependabot alerts API 経由の未解決件数。

---

## レイヤー 6: SAST / SCA / Secret / IaC scan

**目的**：コード・依存・設定・secret を **PR と main の両タイミング** で自動検査し、人間レビューの認知負荷を機械で吸収する。

**主な脅威**
- コードレベルの脆弱性（SQLi, XSS, path traversal, RCE）
- 既知 CVE を持つ依存
- ハードコードされた secret
- IaC のセキュリティ設定ミス（public S3、open security group 等）
- container image の脆弱性

**コントロール**
- SAST：CodeQL（GitHub native、SARIF 統合、`security-extended` query）／ Semgrep
- SCA：Trivy（fs / config / image）／ Snyk
- Secret：Gitleaks（pre-commit + CI 二段）／ GitHub Secret Scanning
- IaC：Trivy config / Checkov / tfsec
- 全結果を SARIF で GitHub Code Scanning に集約 → Security タブで一元化
- 「PR で blocking」と「main で報告のみ」を分ける（Trivy gate のように CRITICAL のみ blocking）

**フレームワーク対応**

| | |
|---|---|
| Scorecard | SAST |
| OWASP CI/CD | CICD-SEC-3, 9 |
| SSDF | PW.6.1, PW.7.2 |

**自リポ実装**：✅ CodeQL（python/go、Phase 5 で JS/TS 追加）／Trivy fs+config 二系統＋ gate job ／Gitleaks ／pre-commit。

**スキル自動化観点**：audit で workflow から各種 scan の有無検出、scaffold で標準セットを投入、Code Scanning API で未対応 alert 件数取得。

---

## レイヤー 7: Build & Artifact

**目的**：「成果物が確かにこの commit からこの環境でビルドされた」ことを **後から検証可能** にする。

**主な脅威**
- ビルド環境への侵入で signed artifact に悪意混入（SolarWinds 型）
- 中間者攻撃でのアーティファクト差し替え
- バージョン文字列の偽装

**コントロール**
- SBOM 生成（CycloneDX / SPDX）— Syft / `actions/sbom-action`
- Provenance（SLSA L1+）— `actions/attest-build-provenance`
- 成果物署名（cosign / sigstore keyless）
- リリース成果物への SBOM/署名添付
- ビルド runner の隔離（hosted / ephemeral）
- 再現可能ビルド（可能な範囲で）
- registry での署名検証（admission control）

**フレームワーク対応**

| | |
|---|---|
| Scorecard | Signed-Releases, Binary-Artifacts |
| OWASP CI/CD | CICD-SEC-4, 9 |
| SSDF | PS.2, PS.3 |
| SLSA | L1–L3 |

**自リポ実装**：⚠️ SBOM (CycloneDX + SPDX) は生成・添付済み。署名 / provenance は未導入（学習リポ初期）。

**スキル自動化観点**：scaffold で SBOM workflow 生成、audit で SLSA Build Level 自己評価、provenance 未導入なら GitHub `attest-build-provenance` 追加提案。

---

## レイヤー 8: Runtime / Container

**目的**：仮にアプリやコンテナが侵入されても、**横展開と権限昇格を最小化** する。

**主な脅威**
- 過剰なケーパビリティを持つコンテナの実行
- ホストネットワーク・ホストファイルシステムへのアクセス
- root 実行
- 外部公開すべきでないポートのリスニング
- ハードコードされた弱パスワード・初期 secret

**コントロール**
- `cap_drop: [ALL]` 後に必要分のみ追加
- `read_only: true`（書き込みは tmpfs 経由）
- `user: <non-root uid>` 指定
- `security_opt: [no-new-privileges:true]`
- リソース上限（`mem_limit`, `pids_limit`）
- ポートは `127.0.0.1:` バインドで loopback 限定
- secret は `${VAR}` で `.env` 経由、デフォルト弱パスフォールバック禁止
- distroless / scratch ベースイメージ
- runtime image の SCA（Trivy image scan）
- production：admission controller（OPA Gatekeeper / Kyverno）

**フレームワーク対応**

| | |
|---|---|
| Scorecard | — |
| OWASP CI/CD | CICD-SEC-7 |
| SSDF | PW.4.4 |
| CIS | CIS Docker Benchmark |

**自リポ実装**：△ docker-compose に hardening 余地（パスワードハードコード、全ポート 0.0.0.0 バインド、cap_drop/read_only 未指定）。dev 用途では許容範囲だが、Trivy config-scan が拾う。

**スキル自動化観点**：audit で `docker compose config` を解析し CIS Docker Benchmark 該当項目を評価。scaffold は `127.0.0.1:` バインド・最小権限の compose テンプレを生成。

---

## レイヤー 9: Disclosure & Incident Response

**目的**：脆弱性が見つかったあとの **受領・評価・修正・公開** までを、外部研究者が動きやすい形で整える。

**主な脅威**
- 脆弱性が公開 issue で晒される
- 報告者が放置されて公開（フルディスクロージャ）に流れる
- メンテナ不在で対応遅延
- 同じ脆弱性の再発

**コントロール**
- `SECURITY.md` に **private vulnerability reporting** URL と SLA 明記
- GitHub Private Vulnerability Reporting (PVR) 有効化
- 連絡窓口の冗長化（メール + フォーム + GitHub PVR）
- 受領 → 評価 → 修正 → CVE 採番 → 公開のランブック
- Dependabot 緊急 alert を issue 化する自動ワークフロー（`security-issue.yml` 型）
- 修正後の post-mortem を ADR / blog 化（学習プロジェクトでは特に推奨）

**フレームワーク対応**

| | |
|---|---|
| Scorecard | Security-Policy |
| OWASP CI/CD | CICD-SEC-10（観測の側面） |
| SSDF | RV.1, RV.2, RV.3 |

**自リポ実装**：✅ `SECURITY.md` に PVR URL + SLA、`security-issue.yml` で 6h cron critical alert → issue 自動化。

**スキル自動化観点**：audit で `SECURITY.md` の必須要素チェック（連絡先・SLA・PVR URL）、PVR 有効化チェック。

---

## レイヤー間の重なり（意図的な多重化）

| 脅威 | 防御層 |
|---|---|
| 単一メンテナ乗っ取り | 1 (CONTRIBUTING で外部不可明記) + 2 (CODEOWNERS + required reviews) + 3 (workflow 最小権限) |
| 依存パッケージ汚染 | 5 (Renovate + digest pin) + 6 (Trivy SCA) + 9 (alert→issue) |
| CI トークン窃取 | 3 (permissions) + 4 (OIDC) + 6 (gitleaks) + 8 (harden-runner) |
| Artifact 改ざん | 6 (Trivy image scan) + 7 (SBOM + sigstore) |
| 脆弱性発見後の事故拡大 | 5 (auto-merge of patches) + 9 (PVR + 自動 issue) |

「同じ脅威に対して 2–3 層が独立に効く」のが多層防御の要点。1 層が破られても次で止まる。

---

## 章立てとの対応（記事執筆時マッピング）

| レイヤー | 記事の章 |
|---|---|
| 1 Repo Policy | 章 4 |
| 2 Branch Protection | 章 5 |
| 3 CI/CD Hardening | 章 6 |
| 4 Identity & Secrets | 章 6 後半 / 章 7 一部 |
| 5 Dependencies | 章 7 |
| 6 SAST/SCA/Secret/IaC | 章 8 |
| 7 Build & Artifact | 章 9 |
| 8 Runtime / Container | 章 10 |
| 9 Disclosure & IR | 章 11 |

---

## スキルでの自動化対応マップ

| レイヤー | audit | scaffold | scorecard |
|---|---|---|---|
| 1 Repo Policy | ✅ ファイル存在＋ URL 検証 | ✅ テンプレ生成 | ✅ Security-Policy |
| 2 Branch Protection | ✅ API 経由設定取得 | ✅ IaC 生成 | ✅ Branch-Protection |
| 3 CI/CD Hardening | ✅ workflow AST 解析 | ✅ 標準 workflow 群 | ✅ Token-Permissions, Dangerous-Workflow |
| 4 Identity & Secrets | ✅ gitignore + gitleaks | △ scaffold は限定（人間設定） | — |
| 5 Dependencies | ✅ renovate / dependabot 設定 | ✅ renovate.json | ✅ Dependency-Update-Tool, Vulnerabilities |
| 6 SAST/SCA/Secret/IaC | ✅ workflow 検出 | ✅ codeql/trivy/gitleaks/sbom | ✅ SAST |
| 7 Build & Artifact | ✅ SBOM workflow + provenance | ✅ workflow 生成 | ✅ Signed-Releases |
| 8 Runtime / Container | ✅ docker-compose 解析 | ✅ ハードン compose | — |
| 9 Disclosure & IR | ✅ SECURITY.md 内容検証 | ✅ テンプレ + IR runbook | ✅ Security-Policy |
