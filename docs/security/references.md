# 参照資料リスト

> 記事執筆時の引用元と裏取り用リンク集。
> 各項目は本文 / 章別マッピングからリンクされる前提。

## 1. 公式仕様・ガイドライン

### OpenSSF
- OpenSSF Scorecard：<https://github.com/ossf/scorecard>
- Scorecard checks 一覧：<https://github.com/ossf/scorecard/blob/main/docs/checks.md>
- OpenSSF Best Practices Badge：<https://www.bestpractices.dev>
- Allstar (GitHub App)：<https://github.com/ossf/allstar>
- SLSA v1.0 Spec：<https://slsa.dev/spec/v1.0/>
- SLSA Threats & Mitigations：<https://slsa.dev/spec/v1.0/threats>

### NIST
- SSDF (SP 800-218)：<https://csrc.nist.gov/projects/ssdf>
- SP 800-218 PDF：<https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf>
- SP 800-204D (CI/CD)：<https://csrc.nist.gov/pubs/sp/800/204/d/final>

### OWASP
- CI/CD Security Top 10：<https://owasp.org/www-project-top-10-ci-cd-security-risks/>
- DevSecOps Maturity Model (DSOMM)：<https://owasp.org/www-project-devsecops-maturity-model/>

### CIS
- CIS Software Supply Chain Security Guide：<https://www.cisecurity.org/insights/white-papers/cis-software-supply-chain-security-guide>
- CIS Benchmarks（Docker / Kubernetes 等）：<https://www.cisecurity.org/cis-benchmarks>

### GitHub 公式
- Securing your end-to-end supply chain：<https://docs.github.com/en/code-security/supply-chain-security>
- Branch protection rules：<https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- About code scanning (CodeQL)：<https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning>
- Hardening for GitHub-hosted runners：<https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions>
- Push protection / secret scanning：<https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning>

## 2. 主要ツール

| 領域 | ツール | URL |
|---|---|---|
| 設定スキャン | Legitify | <https://github.com/Legit-Labs/legitify> |
| Runner 防御 | step-security/harden-runner | <https://github.com/step-security/harden-runner> |
| 依存更新 | Renovate | <https://docs.renovatebot.com> |
| 依存更新 | Dependabot | <https://docs.github.com/en/code-security/dependabot> |
| SAST | CodeQL | <https://codeql.github.com> |
| SAST/SCA | Semgrep | <https://semgrep.dev> |
| SCA/IaC/Container | Trivy | <https://trivy.dev> |
| Secret scan | Gitleaks | <https://github.com/gitleaks/gitleaks> |
| SBOM | Syft | <https://github.com/anchore/syft> |
| 署名 | sigstore / cosign | <https://www.sigstore.dev> |
| Provenance | actions/attest-build-provenance | <https://github.com/actions/attest-build-provenance> |
| OSS 脆弱性 DB | OSV.dev | <https://osv.dev> |
| OSS 脆弱性 DB | GHSA | <https://github.com/advisories> |

## 3. 攻撃事例の一次資料

| 事例 | リンク |
|---|---|
| xz-utils CVE-2024-3094 | <https://research.swtch.com/xz-timeline> |
| xz oss-security ML | <https://www.openwall.com/lists/oss-security/2024/03/29/4> |
| Codecov bash uploader | <https://about.codecov.io/security-update/> |
| PyTorch torchtriton | <https://pytorch.org/blog/compromised-nightly-dependency/> |
| node-ipc protestware | <https://snyk.io/blog/peacenotwar-malicious-npm-node-ipc-package-vulnerability/> |
| SolarWinds CISA advisory | <https://www.cisa.gov/news-events/cybersecurity-advisories/aa20-352a> |
| Ledger Connect Kit | <https://www.ledger.com/blog/a-letter-from-ledgers-ceo-pascal-gauthier-regarding-ledger-connect-kit-exploit> |
| tj-actions/changed-files | <https://www.stepsecurity.io/blog/harden-runner-detection-tj-actions-changed-files-action-is-compromised>（要確認） |

## 4. 産業レポート（年次の引用に使う）

- Sonatype State of the Software Supply Chain：<https://www.sonatype.com/state-of-the-software-supply-chain>
- Snyk State of Open Source Security：<https://snyk.io/reports/open-source-security/>
- GitHub Octoverse / Security：<https://github.blog/category/security/>
- Mend (旧 WhiteSource) Open Source Risk Report：<https://www.mend.io/resources/research-reports/>
- ENISA Threat Landscape for Supply Chain：<https://www.enisa.europa.eu>

## 5. 参考になる既存記事・解説

- Google: Securing the Software Supply Chain（whitepaper） — 検索キー：`google securing software supply chain whitepaper`
- GitHub: Securing your supply chain — 上記 GitHub docs
- Honeycomb / Mend / Snyk のブログから、執筆時に最新の良記事を 2–3 件選定
- Trail of Bits 各種ブログ記事：<https://blog.trailofbits.com/>

## 6. Claude Code プラグイン関連

- 公式 docs: <https://code.claude.com/docs/en/plugins>
- 公式マーケットプレース: <https://github.com/anthropics/claude-plugins-official>
- 公式セキュリティレビュー Action: <https://github.com/anthropics/claude-code-security-review>
- Plugins reference: <https://code.claude.com/docs/en/plugins-reference>

## 7. 引用ポリシー（自分用メモ）

- 数字（影響規模、CVE 番号、日付）は**必ず一次資料で再確認**
- 古い記事の場合、執筆時点での状態を `(2024 年時点)` の形で明記
- 攻撃者・組織名は CVE / advisory に記載のあるもののみ
- セキュリティベンダーのブログを引用する場合は中立的なものを優先
