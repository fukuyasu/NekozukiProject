---
agent: "agent"
description: "実装済みIssueの証拠を集め、学生との対話を通じてdocs/tempのPR本文を作成する"
---

PRを作成・pushしない。一度に複数段階の質問をしない。
Issue・差分・テストを確認するコマンドの実行許可を求める場合は、`AGENTS.md` に従って目的、対象、コマンド、変更の有無を先に説明する。

1. 現在のブランチ名からIssue番号を読み取る。読み取れない場合だけ学生へIssue番号を質問する。
2. Issue本文のAC、GitHub上のMilestone、git差分、直近のcommitを確認する。Milestoneが空欄ならIssueへ既存のlec06～lec14を設定するよう案内して停止する。
3. 最初に「何を実装したか」と「実装上で苦労した点」を質問して停止する。
4. 回答後にIssueのAC一覧を示し、ACごとの確認結果を質問して停止する。
5. 回答後に、`docs/project.md` の `app_dir` のフォルダで実行した `./gradlew test` の結果を質問して停止する。
6. 回答を得たら、`docs/temp/` がなければ作成し、`docs/temp/pr-<Issue番号>.md` を作成または上書きする。
7. PR本文は次の見出しを各1回ずつ使い、すべてに具体的な内容を書く。`関連Issue` には実在するIssue番号を含める。Issueを完了させる `Closes #<Issue番号>` は、そのIssueがOpenの場合だけ使い、完了済みIssueの参照には `Refs #<Issue番号>` を使う。

   ```md
   ## 関連Issue
   Closes #<Issue番号>

   ## 変更内容
   ## AC確認結果
   ## テスト結果
   ```
8. 作成したファイルのパスと、学生が次に `bash scripts/pr/create-pr.sh lecXX` を実行して登録することを報告する。このスクリプトはMilestoneが空欄またはGitHub上に存在しない場合、作成前に停止することも伝える。
