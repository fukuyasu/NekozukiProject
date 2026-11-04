# GitHub Copilot向け追加指示

## 共通作業契約

リポジトリ全体の作業契約の正本は、リポジトリ直下の `AGENTS.md` である。対象IssueのAC、依存関係、変更境界、学生の承認、ローカル参考実装の扱いは、必ずその契約に従う。共通DoDの正本は `docs/project.md` である。同じ規則をこのファイルに重複して書かない。

## Copilot Chatでの作業

- `/brainstorm`、`/plan-issues`、実装、デバッグを始める前に、`docs/project.md` の `PROJECT-CONFIG` にある `app_dir` が設定済みか確認する。未設定なら `/init-project` を案内する。
- 学生が `.github/prompts/` のPromptを選んだ場合は、そのPromptの段階・停止条件を守る。
- 実装、障害診断では、該当する `.github/skills/` のSkillを優先して利用する。PR本文準備、レビューでは、該当する `.github/prompts/` のPromptを選んだ場合は、そのPromptの段階・停止条件を守る。
- Javaファイルまたはテストファイルを扱う場合は、対応する `.github/instructions/*.instructions.md` の規則を適用する。

## 実行・確認

- Gradleの実行場所と確認方法は `AGENTS.md` の作業契約に従う。
- コマンド・スクリプトやGitHub操作の実行許可を求める前の説明も、`AGENTS.md` の作業契約に従う。
- 実行していないテストや手動確認を、実施済みとして報告してはならない。
- Copilot code reviewでは、対象IssueのAC、変更境界、関連テスト、共通DoD、不要なDBスキーマ変更を重点的に確認する。
- あらゆる作業において、ドキュメントと既存のコードが食い違うときはコードの書き方に従い、見つけた食い違いを最後の返答ですべて挙げること
