# セキュリティフレームワーク・マッピング

> 記事「公開リポジトリの多層防御」と Skill `secure-repo-toolkit` 共通の知識ベース。
> 各フレームワークの概要 + 相互マッピング表 + 自リポでの該当実装。

## 1. 主要フレームワーク一覧

| ID | フレームワーク | 目的 | 自動評価 | 配布元 |
|---|---|---|---|---|
| OSSF-SC | OpenSSF Scorecard | リポジトリのセキュリティ姿勢を 0–10 でスコア化 | ✅ 自動 | OpenSSF |
| OWASP-CICD | OWASP CI/CD Security Top 10 (2022) | CI/CD パイプライン固有リスク 10 件 | ❌ 手動 | OWASP |
| SSDF | NIST SP 800-218 (SSDF) | 安全な開発ライフサイクル全体 | ❌ 手動 | NIST |
| 800-204D | NIST SP 800-204D | CI/CD パイプライン特化 | ❌ 手動 | NIST |
| SLSA | SLSA v1.0 | サプライチェーン provenance / Build Level | 部分自動 | OpenSSF |
| OSSF-BP | OpenSSF Best Practices Badge (CII) | OSS プロジェクト基本要件のチェックリスト | 部分自動 | OpenSSF |
| CIS-SC | CIS Software Supply Chain Security Guide | サプライチェーン全般 | ❌ 手動 | CIS |

---

## 2. OpenSSF Scorecard — 全チェック

> 出典: <https://github.com/ossf/scorecard/blob/main/docs/checks.md>
> 各チェックは 0–10 でスコア。重み付け平均で総合スコアが決まる。
> 重み: High = 10, Medium = 7, Low = 3 (run時の `--checks` で個別実行可)

| # | Check | 重み | 何を見る | 主要対策 |
|---|---|---|---|---|
| 1 | Binary-Artifacts | High | リポ内にバイナリ成果物が混入していないか | バイナリは git LFS / リリース成果物に隔離 |
| 2 | Branch-Protection | High | デフォルトブランチが保護されているか（required reviews / status checks / signed commits / linear history） | GitHub Branch Protection rules を IaC で適用 |
| 3 | CI-Tests | Low | PR 時に CI テストが走っているか | GitHub Actions の `pull_request` トリガー |
| 4 | CII-Best-Practices | Low | OpenSSF Best Practices Badge を取得しているか | <https://www.bestpractices.dev> で申請 |
| 5 | Code-Review | High | マージ前にレビューが行われているか（直近の merge を確認） | required reviewers + CODEOWNERS |
| 6 | Contributors | Low | 過去 5 commit で 3 つ以上の異なる組織からの貢献があるか | OSS としての健全性指標、個人リポでは取りにくい |
| 7 | Dangerous-Workflow | Critical | `pull_request_target` での checkout、untrusted input の `${{ }}` 展開等の危険パターンが無いか | actionlint / 静的検査、`pull_request_target` の使用回避 |
| 8 | Dependency-Update-Tool | High | Dependabot / Renovate などが設定されているか | `.github/dependabot.yml` または `renovate.json` |
| 9 | Fuzzing | Medium | fuzz テストが回っているか（OSS-Fuzz / cargo-fuzz / go-fuzz） | OSS-Fuzz 登録または独自 fuzz |
| 10 | License | Low | LICENSE ファイルがあるか（OSI 承認推奨） | `LICENSE` をリポルートに |
| 11 | Maintained | High | 過去 90 日に活動があるか | 定期的なコミット |
| 12 | Packaging | Medium | パッケージとして公開されているか（npm / PyPI / crates 等） | リリース自動化ワークフロー |
| 13 | Pinned-Dependencies | Medium | 依存（GitHub Actions, Docker, npm 等）が SHA や digest で固定されているか | Renovate の `pinDigests: true`、Actions の full SHA 指定 |
| 14 | SAST | Medium | SAST ツールが PR で走っているか | CodeQL / Semgrep / Snyk Code |
| 15 | Security-Policy | Medium | `SECURITY.md` があり、報告先と SLA が書かれているか | Private Vulnerability Reporting + email |
| 16 | Signed-Releases | High | 直近 5 リリースが署名されているか | sigstore cosign / GPG 署名 |
| 17 | Token-Permissions | High | workflow の `GITHUB_TOKEN` が最小権限で書かれているか | `permissions:` ブロックで明示 (`contents: read` など) |
| 18 | Vulnerabilities | High | 既知の脆弱性が残っていないか（osv.dev 参照） | Dependabot alerts を解消 |
| 19 | Webhooks | Low | webhook が HTTPS / token 検証されているか（experimental） | repo 設定要点検 |

実行：
```bash
docker run -e GITHUB_AUTH_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
  --repo=github.com/<owner>/<repo> --format=json
```

> 注：Webhooks check は experimental。stable 版での評価では除外されることがある。

---

## 3. OWASP CI/CD Security Top 10 (2022)

> 出典: <https://owasp.org/www-project-top-10-ci-cd-security-risks/>
> 「CI/CD パイプラインを攻撃面として捉えた」脅威ベースの 10 件。

| ID | 名称 | 攻撃シナリオ要約 | 主要対策 |
|---|---|---|---|
| CICD-SEC-1 | Insufficient Flow Control Mechanisms | レビューや承認を経ずにコード／設定がデプロイされる | Branch protection, CODEOWNERS, required reviews, environment approvals |
| CICD-SEC-2 | Inadequate Identity and Access Management | 過剰な権限の人間／サービスアカウント、孤立アカウント | Just-in-Time access, SSO + MFA, アカウント棚卸し |
| CICD-SEC-3 | Dependency Chain Abuse | 依存パッケージ経由の悪意混入（typosquatting, dependency confusion） | レジストリホワイトリスト、内部 mirror, SBOM 検証 |
| CICD-SEC-4 | Poisoned Pipeline Execution (PPE) | PR から CI を悪用し secret 窃取／成果物改ざん（`pull_request_target` の典型悪用） | `pull_request` のみで untrusted code を扱う、checkout に SHA 指定、untrusted input を `env:` 経由で渡さない |
| CICD-SEC-5 | Insufficient PBAC (Pipeline-Based Access Controls) | パイプラインが過剰権限で走り、横展開可能 | OIDC + ephemeral credentials, environment scoping, runner ハードニング |
| CICD-SEC-6 | Insufficient Credential Hygiene | secret の漏洩、長期 PAT、リポ間共有 | secret scanning, short-lived token, OIDC, Push Protection |
| CICD-SEC-7 | Insecure System Configuration | runner / SCM / build server の脆弱設定 | self-hosted runner の隔離、SCM の hardening, MFA 強制 |
| CICD-SEC-8 | Ungoverned Usage of 3rd Party Services | 未審査の GitHub App / 外部 Action がリポへ広範権限 | Action 許可リスト、App スコープ最小化、定期棚卸し |
| CICD-SEC-9 | Improper Artifact Integrity Validation | ビルド成果物の改ざん検出不可 | SLSA provenance, sigstore 署名、Trivy verify |
| CICD-SEC-10 | Insufficient Logging and Visibility | 攻撃の痕跡が残らない／観測できない | audit log 保管、異常検知、admin action alerting |

---

## 4. NIST SSDF (SP 800-218) 主要プラクティス

> 出典: <https://csrc.nist.gov/projects/ssdf>
> 4 グループ × 約 42 タスク。記事で深く扱うのは PW / RV のみ。

| グループ | 名称 | 主な内容 | 本記事の章への対応 |
|---|---|---|---|
| PO | Prepare the Organization | 役割・ツール・トレーニング・人員 | 章 1, 14 |
| PS | Protect the Software | 改ざん防止・保管・配布 | 章 9 (SBOM/SLSA) |
| PW | Produce Well-Secured Software | 設計・実装・レビュー・テスト | 章 4–10 (本記事メイン) |
| RV | Respond to Vulnerabilities | 受領・分析・修正・公開 | 章 11 (Disclosure) |

代表的タスク（記事で個別に触れるもの）：
- PW.4.1: Secure-by-default 設定の採用
- PW.5.1: 安全なコーディング規約
- PW.6.1: SAST / DAST / SCA の自動実行
- PW.7.1: コードレビューの実施
- PW.8.2: 安全な build 環境
- RV.1.1: 脆弱性受領窓口の整備
- RV.2.1: 脆弱性影響評価
- RV.3.4: 修正の根本原因分析

---

## 5. NIST SP 800-204D（CI/CD 特化）

> 出典: <https://csrc.nist.gov/pubs/sp/800/204/d/final>
> マイクロサービスと CI/CD 向けの secure deployment ガイドライン。記事では「公的根拠」として注記レベルで使う。

主な勧告：
- ソースコード保護: コミット署名、保護ブランチ、CODEOWNERS
- ビルドパイプライン保護: パイプライン定義の改ざん防止、最小権限
- 配布保護: artifact 署名、レジストリ認証、admission control
- 観測: 全段階の audit log とトレース

---

## 6. SLSA v1.0 Build Track

> 出典: <https://slsa.dev/spec/v1.0/levels>
> 「ビルド成果物がどれだけ改ざんされにくいか」のレベル。

| Level | 要件 | 達成手段 |
|---|---|---|
| L1 | provenance を生成して配布する | `actions/attest-build-provenance` 等 |
| L2 | hosted build platform + 署名付き provenance | GitHub-hosted runner + sigstore 署名 |
| L3 | 隔離されたビルド環境、provenance が偽装不可能 | reusable workflow 制約 + OIDC + ephemeral runner |

> 補足: 2024 年以降 GitHub Actions の `attest-build-provenance` で L2 を比較的容易に達成可能になった。

---

## 7. クロスマッピング表

主要レイヤー × フレームワーク。記事 Phase 4 で各章の冒頭に貼る。

| レイヤー | Scorecard | OWASP CI/CD | SSDF |
|---|---|---|---|
| Repo Policy | Security-Policy, License | — | PO.5, RV.1.1 |
| Branch Protection | Branch-Protection, Code-Review | CICD-SEC-1 | PW.7.1 |
| CI/CD Hardening | Token-Permissions, Dangerous-Workflow, Pinned-Dependencies | CICD-SEC-4, 5, 7 | PW.8 |
| Identity / Secrets | — | CICD-SEC-2, 6 | PS.1 |
| Dependencies | Dependency-Update-Tool, Vulnerabilities, Pinned-Dependencies | CICD-SEC-3, 8 | PW.4 |
| SAST/SCA/Secret/IaC | SAST | CICD-SEC-3 | PW.6.1, PW.7.2 |
| Build & Artifact | Signed-Releases, Binary-Artifacts | CICD-SEC-9 | PS.2, PS.3 |
| Runtime / Container | — | CICD-SEC-7 | PW.4.4 |
| Disclosure & IR | Security-Policy | CICD-SEC-10 | RV.* |

---

## 8. 自リポでの該当実装

> Phase 2（Scorecard 実走）で更新する暫定マッピング。
> 凡例: ✅ 実装済 / ⚠️ 部分実装 / ❌ 未実装 / N/A 該当外

| Scorecard Check | 実装状況 | 該当ファイル / 補足 |
|---|---|---|
| Binary-Artifacts | ✅ | バイナリ無し、`.gitignore` で `target/`, `dist/` 等除外 |
| Branch-Protection | ✅ | `infra/live/_bootstrap/main.tf` で有効化。required checks: `ci / gate`, `codeql / gate`, `trivy / gate`, `gitleaks / gate` + signed commits + linear history。`tofu apply` は手動 |
| CI-Tests | ✅ | `.github/workflows/ci.yml`、PR で changes フィルタ→各言語 lint |
| CII-Best-Practices | ❌ | バッジ未取得、Phase 4 で検討 |
| Code-Review | ✅ | CODEOWNERS 必須レビュー + branch protection で強制 |
| Contributors | N/A | 個人プロジェクト想定 |
| Dangerous-Workflow | ⚠️ | `.github/workflows/auto-merge.yml` が `pull_request_target` 使用、actor 制限あり |
| Dependency-Update-Tool | ✅ | Renovate + Dependabot 二段 |
| Fuzzing | ❌ | 未導入、学習リポでは優先度低 |
| License | ✅ | `LICENSE` (Apache-2.0 想定、要確認) |
| Maintained | ✅ | 最近のコミットあり |
| Packaging | N/A | パッケージ配布なし |
| Pinned-Dependencies | ✅ | Renovate `pinDigests: true`、Actions full SHA 指定 |
| SAST | ✅ | `.github/workflows/codeql.yml` (security-extended) |
| Security-Policy | ✅ | `SECURITY.md` |
| Signed-Releases | ❌ | 未導入、Phase 9 で sigstore 検討 |
| Token-Permissions | ✅ | 全 workflow に `permissions:` 明示 |
| Vulnerabilities | ✅ | Dependabot alerts、`security-issue.yml` で 6h cron 通知 |
| Webhooks | N/A | webhook 未使用 |

| OWASP CI/CD Top 10 | 実装状況 | 補足 |
|---|---|---|
| CICD-SEC-1 Flow Control | ✅ | branch protection + required reviews/checks を適用済み |
| CICD-SEC-2 IAM | N/A | 1 名運営、SSO/MFA は GitHub 設定（要確認） |
| CICD-SEC-3 Dependency Chain | ✅ | digest pin + Trivy |
| CICD-SEC-4 PPE | ⚠️ | `pull_request_target` 使用箇所あり |
| CICD-SEC-5 PBAC | ✅ | `permissions:` 最小化 |
| CICD-SEC-6 Credential Hygiene | ✅ | secret scanning + gitleaks 二段、PAT は `.env`、`SecretStr` |
| CICD-SEC-7 System Config | ✅ | hosted runner のみ |
| CICD-SEC-8 3rd Party | ✅ | 全 Action が full SHA pin、Renovate 管理 |
| CICD-SEC-9 Artifact Integrity | ⚠️ | SBOM あり、ただし署名なし |
| CICD-SEC-10 Logging | ⚠️ | audit log は GitHub 標準に依存、独自集約なし |

---

## 9. 章別マッピング早見表（記事執筆時に参照）

| 章 | 内容 | 引用フレームワーク |
|---|---|---|
| 4 Repo Policy | SECURITY.md / CODEOWNERS / CONTRIBUTING | Scorecard: Security-Policy, License / SSDF: PO.5, RV.1.1 |
| 5 Branch Protection | required reviews / status checks / signed commits | Scorecard: Branch-Protection, Code-Review / OWASP: CICD-SEC-1 / SSDF: PW.7.1 |
| 6 CI/CD Hardening | minimum permissions / SHA pin / `pull_request_target` の罠 | Scorecard: Token-Permissions, Dangerous-Workflow / OWASP: CICD-SEC-4, 5 |
| 7 Dependencies | Renovate vs Dependabot / digest pin | Scorecard: Dependency-Update-Tool, Pinned-Dependencies, Vulnerabilities / OWASP: CICD-SEC-3, 8 |
| 8 SAST/SCA/Secret/IaC | CodeQL / Trivy / Gitleaks | Scorecard: SAST / SSDF: PW.6.1 |
| 9 Build & Artifact | SBOM / SLSA / sigstore | Scorecard: Signed-Releases, Binary-Artifacts / OWASP: CICD-SEC-9 / SLSA L1–3 |
| 10 Runtime / Container | docker hardening | OWASP: CICD-SEC-7 |
| 11 Disclosure & IR | private VR / 自動 issue 化 | Scorecard: Security-Policy / SSDF: RV.* |
