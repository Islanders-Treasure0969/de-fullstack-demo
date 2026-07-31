# 既存ツール・プラグイン調査

> `secure-repo-toolkit` プラグイン構築前の prior art 調査結果。
> 出典：claude-code-guide エージェント調査（要 1 次確認の項目あり）。

## 結論

**ゼロから作らず、既存 CLI（OpenSSF Scorecard / Legitify / step-security/harden-runner）を Claude プラグインでラップする。** 公式・コミュニティに同種プラグインは存在しないが、**評価ロジック自体は成熟した CLI が複数あり**、Claude 側は「結果の解釈・優先度付け・修正コード提案・差分適用」というバリュー部分に集中するのが効率的。

---

## A. Anthropic 公式

| 項目 | 内容 | 検証状況 |
|---|---|---|
| 公式マーケットプレース | `anthropics/claude-plugins-official` (≈18.9k stars 規模) | 要 1 次確認 |
| インストール経路 | `/plugin > Discover` または `/plugin install <name>@claude-plugins-official` | 公式 docs で要確認 |
| プラグイン形式 | `.claude-plugin/plugin.json` + `skills/` / `commands/` / `agents/` / `hooks/` / `.mcp.json` | 公式 docs で要確認 |
| 公式セキュリティ | `anthropics/claude-code-security-review`（PR 差分セキュリティレビュー、GitHub Action） | 既存 |
| 想定スコープと重複 | 差分 review のみ。**リポ全体の多層監査・scaffold・Scorecard 連携は未提供** | 重複なし |

公式 docs リンク：
- <https://code.claude.com/docs/en/plugins>
- <https://code.claude.com/docs/en/plugins-reference>
- <https://github.com/anthropics/claude-plugins-official>
- <https://github.com/anthropics/claude-code-security-review>

---

## B. コミュニティ プラグイン / Skill

| プラグイン | 領域 | 重複度 | URL |
|---|---|---|---|
| Trail of Bits Skills | セキュリティ研究、脆弱性検出 | 部分（pentesting 寄り） | <https://github.com/trailofbits/skills> |
| Phoenix Security Skills | OWASP パターン、threat intel | 部分（脅威検知中心） | <https://github.com/Security-Phoenix-demo/security-skills-claude-code> |
| Netresearch Security Audit | PHP 監査特化 | 低（言語特化） | <https://github.com/netresearch/security-audit-skill> |
| awesome-claude-skills-security | SecLists / 攻撃ペイロード | 低（攻撃側） | <https://github.com/Eyadkelleh/awesome-claude-skills-security> |
| 大規模アグリゲータ系 | 数千 skill 集約サイト | 低（品質ばらつき） | 引用見送り |

**重複ギャップ**：いずれも「リポ全体姿勢を Scorecard / OWASP CI/CD Top 10 マップで監査するプラグイン」は提供していない。`secure-repo-toolkit` は新規価値を持つ。

---

## C. 既存 CLI（先行プロダクト）

| ツール | 役割 | ラップ採用 | URL |
|---|---|---|---|
| **OpenSSF Scorecard** | 18 checks の自動評価 | ✅ コア | <https://github.com/ossf/scorecard> |
| **Legitify** | GitHub/GitLab 設定スキャン、Scorecard 連携 | ✅ コア | <https://github.com/Legit-Labs/legitify> |
| OpenSSF Allstar | GitHub App でポリシー強制 | △ 補助（GitHub App として並存） | <https://github.com/ossf/allstar> |
| step-security/harden-runner | runner 実行時の egress / file / process 監視 | ✅ scaffold で提案 | <https://github.com/step-security/harden-runner> |
| Trivy / Gitleaks / CodeQL | scaffold の workflow 内で利用 | ✅ scaffold | （`references.md`） |

---

## D. 隣接エコシステム

| エコシステム | 同種プラグインの有無 | 備考 |
|---|---|---|
| GitHub Copilot | 同種なし（内蔵セキュリティ scan / Autofix のみ） | リポ監査の概念が薄い |
| Cursor / Cline / Aider | 同種プラグインなし | 先行優位を取りやすい |
| Codeium / Continue | 未調査 | 必要なら追加調査 |

---

## E. 推奨アーキテクチャ

```text
secure-repo-toolkit/                 # 独立リポ（公式マーケットプレースに submit 想定）
  .claude-plugin/
    plugin.json                       # name, version, description, author
  commands/
    audit.md                          # /toolkit:audit
    scaffold.md                       # /toolkit:scaffold
    scorecard.md                      # /toolkit:scorecard
  skills/
    layered-audit/
      SKILL.md                        # KB を参照する knowledge skill
  knowledge/                          # docs/security/ の内容を取り込む
    frameworks.md
    layers.md
    attack-cases.md
    references.md
  templates/                          # scaffold が生成するテンプレート群
    SECURITY.md
    CODEOWNERS
    .pre-commit-config.yaml
    workflows/
      ci.yml
      codeql.yml
      trivy.yml
      gitleaks.yml
      sbom.yml
      scorecard.yml
    renovate.json
    branch-protection.tf              # IaC で branch protection
  bin/                                # 補助スクリプト
    run-scorecard.sh                  # Scorecard CLI ラッパ
    run-legitify.sh                   # Legitify CLI ラッパ
  .mcp.json                           # 必要なら MCP サーバ宣言
```

### コマンドの責務分担

| コマンド | 責務 | 出力 |
|---|---|---|
| `/toolkit:audit` | Legitify + Scorecard を実行 → JSON を解析 → KB のフレームワーク表にマッピング → 改善提案差分を**承認待ち**で提示 | `docs/security/audit-report.md` + 提案差分 |
| `/toolkit:scaffold` | 現状リポ検査 → 不足するセキュリティテンプレートを差分提案（既存ファイルは上書きしない） | 差分 PR 候補 |
| `/toolkit:scorecard` | Scorecard をローカル実行（Docker 経由）→ check ごとの修正手順 → KB 該当箇所へリンク | レポート + チェックリスト |

### 出力ポリシー

- すべての書き込み系操作は**承認待ちの差分提示**を経由（手動適用または `--apply` フラグで明示）
- 既存ファイルは上書きしない（diff を `--3way` 風に提示）
- Audit は read-only

---

## F. 残検証事項（プラグイン構築開始前）

- [ ] 公式マーケットプレース URL とインストールコマンドの正確性（`code.claude.com` の docs 一次確認）
- [ ] プラグイン形式の最新仕様（`SKILL.md` フォーマット、frontmatter 必須項目、`commands/*.md` の YAML frontmatter 仕様）
- [ ] Legitify の OSS ライセンス確認（Apache 2.0、利用条件問題なし想定）
- [ ] Scorecard の token 要件と rate limit
- [ ] 公式マーケットプレースへの submit 手順（PR? フォーム?）

これらは「KB → 記事 → プラグイン」の最後のフェーズで一括確認する。
