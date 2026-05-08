# ansible/

VPS / ベアメタルへのセルフホストデプロイ用 playbook。**Phase 6** で実装する。

## 構造

```
ansible/
├── inventory/    # dev (localhost / Vagrant) / prod (VPS)
├── playbooks/    # 01-bootstrap, 02-deploy-app, 03-deploy-multiwoven, 04-tls, 05-backup
└── roles/        # common, docker, observability
```

## 役割分担

| ツール | 担当 |
|-------|------|
| OpenTofu | クラウド/API リソース (what) |
| **Ansible** | VPS の OS / ファイル / プロセス構成 (how) |
| Docker Compose | アプリ本体の起動定義 |
| GitHub Actions | CI/CD パイプライン |

Phase 1-5 はローカル Docker Compose で完結するため、Ansible の出番は Phase 6 から。
