# Issue・Pull Requestテンプレートの制約

このファイルは、学生が使うIssue・Pull Request（PR）の記録形式に関する唯一の根拠である。見出しはすべて1回ずつ置く。必須項目は空欄にできず、任意項目は見出しだけでもよい。

## Issue

| 項目 | 本文 | 備考 |
| --- | --- | --- |
| 機能の概要 | 必須 | できるようになることと、今回しないことを書く。このIssueで使う固有の語は初出時に短く定義する。 |
| AC（受け入れ基準） | 必須 | Givenには誰がどの画面でどの状態かを文で、Whenには人と具体的な操作、Thenには確認する場所と結果を書く。画面や操作が未決定なら質問してから書く。 |
| 関連ファイル・変更境界 | 任意 | 変更予定のファイルと変更してはいけない範囲を書く。 |
| 実装計画 | 任意 | 実装の順序を書く。 |
| 変更しないものとリスク | 任意 | 変更しない範囲と注意点を書く。 |

`depends-on` は空欄、同時に登録する草案のID、または既存のOpen Issue番号をカンマ区切りで記載できる。既存Issue番号は登録スクリプトがOpenであることを検査する。
草案メタデータの `milestone:` は必須で、`lec06`～`lec14` の既存Milestoneを指定する。PRには関連Issueと同じMilestoneを設定する。
GitHub Issue FormのMilestone欄は本文へ転記される入力欄であり、GitHub上のMilestone設定とは別である。直接作成したIssueは `.github/workflows/validate-issue-milestone.yml` が実際の設定値を作成後に検査する。

## Pull Request

| 項目 | 本文 | 備考 |
| --- | --- | --- |
| 関連Issue | 必須 | 実在するIssue番号を `#12` の形式で書く。`Closes #12` は対象IssueがOpenの場合だけ使え、`Refs #12` などの参照はOpen・Closedを問わない。 |
| 変更内容 | 必須 | 変更した利用者価値と主な変更を書く。 |
| AC確認結果 | 必須 | 各ACと、その確認結果・根拠を書く。 |
| テスト結果 | 必須 | `docs/project.md` の `app_dir` のフォルダで実行した `./gradlew test` の結果を書く。 |

## 機械可読な制約

以下は `scripts/harness/generate-template-harness.sh` が読む設定である。見出し名や必須・任意を変えるときは、表とこの設定を同時に更新してから生成スクリプトを実行する。

<!-- HARNESS-CONFIG
issue.headings=機能の概要|AC（受け入れ基準）|関連ファイル・変更境界|実装計画|変更しないものとリスク
issue.required=機能の概要|AC（受け入れ基準）
pr.headings=関連Issue|変更内容|AC確認結果|テスト結果
pr.required=関連Issue|変更内容|AC確認結果|テスト結果
-->
