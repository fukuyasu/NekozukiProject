# プロジェクト概要

<!-- PROJECT-CONFIG
repository_name=NekozukiProject
app_name=nekoselect
app_dir=nekoselect
-->

## 開発者（GitHub名）

`/init-project` が、GitHubから取得した最新の Collaborator 一覧でこのブロックを更新する。各Issueの担当者はGitHub上で管理する。

<!-- COLLABORATORS: START -->
- fukuyasu
- igaki
- kiyoshi-honda
<!-- COLLABORATORS: END -->

## 開発するアプリケーションの条件

具体的なアプリケーションは学生チームの意見を起点に決める。次の条件をすべて満たすこと。

- **A1**: Spring Bootで開発する。
- **A2**: DBを利用する。
- **A3**: 複数の利用者が存在し、利用者間に何らかのインタラクションがある。
- **A4**: チャットや掲示板など、テキスト交換を主目的とするアプリケーションではない。補助的なチャット機能は可とする。
- **A5**: GitHubリポジトリの状態から起動するためのセットアップ手順がある。
- **A6**: 起動後に操作するための、ロール別のユーザマニュアルがある。


## 開発環境

PortableGit Bash を起動して開発する。JDK、Gradle、GitHub CLIのPATH設定は自動で行われる。

`/init-project` を実行して、GitHub認証、SSH remote、Spring Bootアプリ、Gradleテスト、`app_dir` の設定を確認する。

## 現在の構成

- GitHubリポジトリ名・アプリ名・アプリ本体のフォルダ: このファイルの `PROJECT-CONFIG` にある `repository_name`・`app_name`・`app_dir`
- 技術: 学生チームが作成する Spring Boot アプリケーション

## プロジェクトで守る原則

この文書は、全Issueに共通するDoDとドキュメント管理方針の正本である。個別機能の仕様はGitHub Issue、実装済みの振る舞いはテストとマージ済みPRを正本とする。AIとの会話ログや作業途中の下書きを、仕様・実装の根拠として残さない。

## 用語

- **AC（Acceptance Criteria／受け入れ基準）**: 個々のIssueで、その機能を受け入れられるかを判定する観測・テスト可能な条件。原則として Given / When / Then 形式で書く。
- **DoD（Definition of Done／完了の定義）**: すべての実装Issueに共通する、mainへマージして完了扱いにしてよい条件。Issue固有の機能要件は書かない。

### 共通DoD

実装を伴うIssueは、次のすべてを満たしたときに完了とする。

1. すべてのIssueとPRにMilestoneが正しく設定されている。
2. すべてのIssueに担当者とACが記録されている。変更ファイル、実装計画、依存Issueは必要な場合に記録されている。
3. Issueごとのブランチで実装が行われており、PRでマージされている。`main` へ直接コミットしていない。
4. すべてのPRについて、「変更内容」と「AC確認結果」としてACごとの自動テストまたは`./gradlew bootRun` による手動確認の結果と、残る懸念があればその内容が記録されている。
5. すべてのPRについて，「関連Issue」が記述されている．OpenなIssueを完了させる場合は `Closes #番号`、完了済みIssueを参照する場合は `Refs #番号` を使っている。
6. すべてのPRについて、実装者以外がAC・差分・テストをレビューしてからマージしている。

## ドキュメント管理方針

### 正本とGit管理

| 対象 | 用途・正本 | Git管理 |
| --- | --- | --- |
| GitHub Issue | 機能のAC、変更境界、実装計画、依存関係 | GitHub上で管理 |
| Pull Request・レビュー・CI | 実装内容、AC確認、レビュー、マージ根拠 | GitHub上で管理 |
| テスト・コード | 実装済みの振る舞い | 管理する |
| `docs/project.md` | 共通DoD、この方針、リポジトリ名・アプリ名・アプリフォルダ設定 | 管理する |
| `docs/template-constraints.md` | Issue／PRテンプレートの制約 | 管理する |
| `docs/assets/vendor/` | オフライン表示に必要な外部資材とライセンス案内 | 管理する |
| `docs/trouble/` | `debug` Skillが残す個別デバッグ記録 | 管理する |
| `docs/temp/` | ブレインストーミング、Issue草案、PR本文の下書き | 管理しない |
| `docs/ref/springboot_samples/` | 授業配布の読み取り専用参考実装 | 管理しない。変更もしない |
| `docs/weekly-summary_*.html` と `docs/weekly-summary-data/` | 個人のローカル週次振り返り | 管理しない |

### 命名規則

- ブレインストーミングの一時ブリーフ: `docs/temp/brainstorm/<機能slug>(-連番).md`。`<機能slug>` は英小文字・数字・ハイフンのみとする。
- Issue草案: `docs/temp/issues.md`。登録前の一時ファイルであり、次の計画作成時に上書きしてよい。
- PR本文の下書き: `docs/temp/pr-<Issue番号>.md`。同じIssueの再作成時は上書きしてよい。
- 個別デバッグ記録: `docs/trouble/troubleshooting-<GitHubユーザー名>-YYYY-MM-DDTHHMMSS+0900(-連番).md`。JST時刻を秒まで含め、Windowsで使えないコロンは使わない。
- 週次振り返りJSON: `docs/weekly-summary-data/<GitHubユーザー名>/lecXX.json`。同じMilestoneの再集計時は日時付き `.bak` を残して差し替える。HTMLは `docs/weekly-summary_<GitHubユーザー名>.html` とする。いずれもローカル生成物である。

### 作成・変更のルール

1. `/brainstorm`、`/plan-issues`、`/prepare-pr` が作る `docs/temp/` の内容は、学生が確認するための下書きであり、Gitへ追加しない。
2. `debug` Skillは、学生が記録を残すと選んだ場合だけ `docs/trouble/` に個別記録を作る。記録には少なくとも、再現条件、原因、修正、再発防止テストを含める。
3. `weekly-summary.sh` は、Milestone別の個人JSON記録と閲覧用HTMLを作る。再集計時は既存JSONのバックアップを残す。これらをPRへ含めない。
4. プロジェクト全体の前提、共通DoD、文書管理方針を変えるときは、この文書の変更案を学生が確認してから反映する。
