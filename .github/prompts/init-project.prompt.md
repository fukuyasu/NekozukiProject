---
agent: "agent"
description: "ブレインストーミング前に、GitHubリポジトリとSpring Bootアプリの初期化状態を検査・設定する"
---

実装、Issue作成、ブレインストーミングはしない。学生にリポジトリ名やアプリフォルダ名を入力させない。
実行許可を求める前には、`AGENTS.md` に従い、検査または設定更新の目的、実行するコマンド、変更の有無を簡潔に説明する。

1. リポジトリのルートで `bash scripts/harness/init-project.sh --check` を実行する。
2. 出力されたローカル名、GitHubリポジトリ名、SSH remote、Collaborator のGitHub ID一覧、検出されたSpring Bootアプリ、Gradleテスト結果、GitHub main 保護設定を短い表で示す。main 保護設定の「要確認」は警告として伝える。
3. スクリプトが失敗した場合は、失敗した項目を解消するための操作だけを案内して停止する。Collaborator が0人または取得できない場合も停止する。アプリ候補が0件なら、学生が好きな名前で Spring Boot プロジェクトを作成してから再実行するよう案内する。候補が複数なら、候補を整理してからこのプロンプトを再実行するよう案内する。
4. 検査に成功し、`docs/project.md` の `repository_name`、`app_name`、`app_dir` または Collaborator 一覧が未設定・検出結果と異なる場合は、検出結果を示し、`--initialize` による `docs/project.md` 更新の承認を求めて停止する。
5. 学生が承認した場合だけ、`bash scripts/harness/init-project.sh --initialize` を実行する。
6. 更新後の `repository_name`、`app_name`、`app_dir`、Collaborator 一覧を報告し、学生に `docs/project.md` の変更をコミットするよう案内する。コミット後は `/brainstorm` を案内して終了する。
