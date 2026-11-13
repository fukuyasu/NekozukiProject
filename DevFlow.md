# Spring Boot チーム開発テンプレート

4人程度のチームで，Spring Boot とデータベースを使う Web アプリケーションをAIエージェントと一緒に開発するための**手順書**です．上から順に読み，そのとおりに一度は実行して見ましょう．2回目以降も実行するかどうかはチームごとに好きに決めてもらって構いません．この授業ではAIエージェントを含む生成AI利用有無は成績に一切影響しません．

**このマニュアルに書いてあること**: 何を，どの順で，どのコマンドで実行するか．
**このマニュアルに書いていないこと**: 用語の意味と背景．AIエージェントと一緒に開発するための用語ガイドを参照してください．

**入力先の見分け方**: `/init-project` などのPromptや「Skillを使ってください」という依頼は **Copilot Chat** に入力します．`bash`・`gh`・`git`・`./gradlew` で始まるコマンドは，原則としてリポジトリの **ターミナル（Git Bash）** で実行します．「AIが実行する確認コマンド」と記したものは学生が入力する必要はありません．GitHubの画面で行う操作はその都度明記します．

Copilotがコマンドやスクリプトの実行許可を求める場合は，先に表示される**実行の目的・対象・コマンド・変更や投稿の有無**を読んでから判断してください．説明がない，または意図が分からない場合は，許可する前にCopilot Chatで確認してください．

---

## A. このマニュアル全体の流れ

1. プロジェクトの初期化
2. 要求分析(ブレインストーミング)
3. 計画 — a. タスク分割 / b. Issue の作成・登録
4. 実装とテスト，PR 作成・登録
5. レビューとマージ
6. デバッグ

| 工程 | 使うもの | 正式に残る記録(文書) |
| --- | --- | --- |
| 1. 初期化 | `/init-project`，`init-project.sh` | `docs/project.md` のプロジェクト設定 |
| 2. ブレインストーミング | `/brainstorm`，`docs/project.md` | `docs/temp/brainstorm/*.md`(下書き) |
| 3a. タスク分割 | `/plan-issues`，テンプレート制約 | `docs/temp/issues.md`(下書き) |
| 3b. Issue 登録 | Issue Form，登録スクリプト | **GitHub Issue** |
| 4. 実装と PR | `implement-issue` Skill，`/prepare-pr` | コード，テスト，コミット，**GitHub PR** |
| 5. レビュー | PR テンプレート，CI，`/review-pr` | PR 本文，コメント，承認，CI 結果 |
| 6. デバッグ | `debug` Skill，テスト，ログ | 回帰テスト，修正 PR |


`docs/temp/` は AI と相談するための下書きで，**Git に登録しません**．最終的な根拠は Issue，PR，コード，テスト，レビューに残します．

> [!WARNING]
> AC は「何をもって正しいとするか」の唯一の基準です．実装が終わってから都合よく書き換えてはいけません．要求自体が変わった場合だけ，**チームで相談して**更新します．この規則はデバッグ中も同じです．不具合を隠すための書き換えは禁止です．

**このマニュアルの応答例について**: 以下の「AI の応答例」は，このテンプレートの Prompt／Skill の指示に従って得られる応答の例です．実際の応答は Issue・差分・テスト結果で変わります．`(省略)` の部分も必ず読み，納得できない点は質問してください．

## 0. 準備
- プロジェクトの初期化前に下記を実施しておく

1. ローカル/リモートリポジトリを作成する
2. SpringBootプロジェクトを作成し，初期コミットを実施する．
3. Pull Request必須，force push禁止，ブランチ削除禁止等のGitHubリポジトリ設定を行う
4. GitHub CLIの認証を行う

---

## 1. プロジェクトを初期化する（プロンプト: `/init-project`）

学生チームが作成した Spring Boot プロジェクトのアプリフォルダを検出し，docs/project.mdに設定します．アプリフォルダ名を手入力する必要はありません．

### 実施の流れ

1. Copilot Chat で `/init-project` を選ぶ．
2. Prompt が SSH remote，GitHub CLI 認証，Collaborator 一覧，Spring Boot アプリ，Gradleテスト，main 保護設定を検査する．NG項目があれば停止する．main 保護設定が確認できない場合は警告を表示する．
3. 検出したリポジトリ名，アプリ名，アプリフォルダ，Collaborator 一覧を `docs/project.md` に設定する承認を求められたら，内容を確認して承認する．既に記録がある場合も，最新の一覧で更新する．
4. 初期化後，`docs/project.md` を含むすべてのファイルをコミットする．
    - この時点で，GitHubのRulesetsの[Disabled]を[Active]にしておく．
    - これ以降mainブランチに直接コミットは禁止

### 入力例

**入力先: Copilot Chat**

```text
/init-project
```

### AIが実行する確認・更新コマンド

次はPromptが実行するコマンドです．学生がCopilot Chatへ貼り付けるコマンドではありません．

**実行先: AIのターミナル（検査のみ）**

```bash
bash scripts/harness/init-project.sh --check
```

設定更新を承認した場合は，次を実行します．

**実行先: AIのターミナル（`docs/project.md` を更新）**

```bash
bash scripts/harness/init-project.sh --initialize
```

## 1.1. 次へ進む前の確認とリポジトリハーネスの設定

- `docs/project.md` の `PROJECT-CONFIG` に，検出された `repository_name`，`app_name`，`app_dir` が記録されている．
- `## 開発者（GitHub名）` に，取得した最新の Collaborator のGitHub ID一覧が記録されている．
- `app_dir` のフォルダで `./gradlew test` が成功している．
- 以降の `/brainstorm`，`/plan-issues`，Skill，CI は `app_dir` をアプリフォルダとして利用する．

### リポジトリハーネス

---

## 2. ブレインストーミング: 作りたいことを具体的にする(プロンプト: /brainstorm)

「誰が」「何をして」「誰とどう関わり」「何がうれしいか」を言葉にします．この段階では実装や Issue 分割を急ぎません．

### 実施の流れ

1. Copilot Chat で `/brainstorm` (プロンプト)を選ぶ．
2. 自分たちの案を，普段使う言葉で入力する．
3. AI の質問にチームで答える．
4. AI が整理した決まったことと未決定のことを確認する．
5. 追加の要望・質問・修正点があれば，チームの決定を伝える．
6. まとまったら，結果をファイルにまとめるよう指示する．
7. 作成されたファイルの相対パスを，次の `/plan-issues` の入力に使う．

### 入力例

**入力先: Copilot Chat**

```text
/brainstorm 学内イベントで，参加者が同じ企画に参加登録できる機能を追加したいです．
参加する人と主催者には，どんな画面や操作が必要かを一緒に考えたいです．
```

### 相談を進める入力例

AI は `docs/project.md` に基づき，開発対象について「すでに分かっていること／まだ分からないこと／確認したいこと」を整理し，質問を返します(例: 手はグー・チョキ・パーか，全員が選ぶまで隠すか，勝敗や履歴まで扱うか，管理者は必要か)．AI の整理を確認し，追加の決定があれば次のように伝えます．

**入力先: Copilot Chat**

```text
今回は，あらかじめ用意されたルームを選んで入れればよいです．
ルームを新しく作る機能は次回にします．
```

### 次の工程

まとまったらファイル化します．ファイル名を指定しなければ AI が機能名から決めます(同名なら `-2` などの連番)．

**入力先: Copilot Chat**

```text
ブレインストーミング結果をファイルにまとめてください．
```

> `docs/temp/brainstorm/round-choice.md を作成しました．このファイルを /plan-issues の入力として指定してください．`

### 次へ進む前の確認

- チームの全員が，作りたい機能を自分の言葉で説明できる．
- 利用者，主な操作，利用者どうしの関わりが決まっている．
- 今回は作らないことが決まっている．
- Spring Boot，DB，複数ユーザーの相互作用という演習条件を満たす見込みがある．

**残すもの**: 会話の全文は残しません．合意内容だけを `docs/temp/brainstorm/<機能名>.md` に残します．

---

## 3. 計画a: 機能を小さな Issue に分ける(プロンプト: /plan-issues)

各 Issue は，変更内容が大きすぎると，動作確認やテストが困難になるため，新規・変更するファイルを**3個程度を目標，多くても4個程度を目安**に分割します．自動テスト，HTML，SQL，設定ファイルも数に含め，同じ Issue で繰り返し変更するファイルは1個と数えます．ファイル数のために必要なテストを省いたり，無関係な処理を一つのファイルへ詰め込んだりはしません．これは `/plan-issues` で分割案を見直すための目安であり，登録スクリプトが件数で停止するものではありません．

### 実施の流れ

1. Copilot Chat で `/plan-issues` を選ぶ．
2. ブレインストーミング結果の相対パス，または作りたい機能の説明を入力する(両方なければ AI が質問します)．
3. AIの生成したIssueについて，大きすぎる Issue，曖昧な AC，不要な依存関係，予定ファイルの抜けがないかをチームで確認する．4個程度を超える案は，分割案と必要なファイルを確認してから判断する．
4. 合意できたら，AI に Issue の下書き(`docs/temp/issues.md`)を作らせる．
5. `docs/temp/issues.md` を読み，必要な部分だけを修正する．

### 入力例

**入力先: Copilot Chat**

ブレインストーミングから続ける場合はファイルのパスを指定しましょう．別の生成AIを利用した場合など，ブレインストーミング結果をそのまま貼り付けても構いません．

```text
/plan-issues docs/temp/brainstorm/round-choice.md
```

AI はまず内容と関係する既存コード・テスト・設定を確認し，分割案を表で示します(この時点では `docs/temp/issues.md` は作られません)．id・題名・確認できる振る舞い・今回しないこと・依存・予定ファイルと件数・分割理由を確認します．登録とログインのように別々に確認できる振る舞いは段階的に分けます．4個程度を超える場合は分割や既存ファイルの活用を再検討し，なお超える場合は理由と代案を示して相談します．合意後は，次のように入力して草案作成を依頼します．

画面を使うACでは，**Given** に「誰がどの状態でどの画面を開いているか」，**When** に「誰がどのボタン・リンクなどを操作するか」，**Then** に「どの画面・場所に何が表示されるか」を書きます．対応するHTMLテンプレートが決まっていれば，その名前も記します．「ログイン済みプレイヤー」「ゲームを開始する」「クリックする」のように対象や方法が省略されていないか確認してください．「ルーム識別子」など固有の語は同じIssueの「機能の概要」で説明します．画面・操作・権限がまだ決まっていない場合，AIは推測して埋めず，チームに質問します．

### 草案作成の入力例

**入力先: Copilot Chat**

```text
この分け方で進めます．Issue の下書きを作ってください．
```

AI は草案作成時に，各AC・実装計画・関連ファイルの一覧を照合してファイル数を再確認します．見積もりが4個程度を超えたら分割案へ戻り，なお大きいIssueが必要な場合はチームと相談します．草案作成後は，登録スクリプトで形式エラーにならないよう，Issue ブロック数・各 Issue の AC 見出し数・実装計画見出し数などを確認し，その結果と未決定事項を報告します．
この確認は内容の正しさを保証するものではありません．`docs/temp/issues.md` を開き，各 Issue の AC，依存関係，変更範囲，実装計画に問題がないかをチームで確認しましょう．確認後，各 Issue の `assignee:` に担当する学生の GitHub ユーザー名，`milestone:` に `lec06`～`lec14` の既存Milestoneを学生自身が直接記入します．どちらかが未記入なら登録スクリプトは Issue を登録せず停止します．

### 草案を修正する入力例

AC が曖昧なら，**該当箇所だけ**を直すよう依頼しても構いません．

**入力先: Copilot Chat**

```text
docs/temp/issues.md の Issue game-room-join の AC 2 を，
満室のときに参加できないことを確認できる書き方に直してください．
ほかの Issue は変更しないでください．
```

### 次へ進む前の確認

- 各 Issue に「機能の概要」「AC」があり，必要に応じて変更境界・実装計画・リスクも記載されている．
- AC を読めば，実装後に何を確認すればよいか分かる．
- Issue ごとの担当と依存関係を決められる．
- 一人が説明できないほど大きい Issue になっていない．

**残すもの**: `docs/temp/issues.md` は登録前だけの下書きです．登録後は **Issue 本文が正式な機能仕様**になります．

---

## 4. 計画b: Issue を登録する(スクリプト:register-from-file.sh)

チームで確認し，担当者とMilestoneを記入した Issue 草案を GitHub Issue として登録します．**IssueにMilestoneを設定する前に，指定するMilestone自体をGitHubリポジトリ上で作成してください．** `milestone: lec06` と草案に書いただけではMilestone自体は作成されません．未作成ならGitHubに登録してから進みます．

### 実施の流れ

1. `docs/temp/issues.md` の内容をチームで確認する．
2. 各 Issue の `assignee:` に担当する学生の GitHub ユーザー名，`milestone:` にGitHubで作成済みの `lec06`～`lec14` を記入する．
3. 登録スクリプトをターミナルで実行する．スクリプトは指定したMilestoneを各IssueのGitHub上の設定に割り当てる．
4. 作成されたIssueをGitHubで開き，右側のMilestone欄に指定値が設定されていることを確認する．エラーが出た場合は，指摘された箇所だけを修正して再実行する．

### 実行コマンド

**入力先: ターミナル（Git Bash）**

```bash
bash scripts/issue/register-from-file.sh docs/temp/issues.md
```

スクリプトは質問をせず，草案を検査して問題がなければ登録します．**GitHubのIssue Formから直接登録するときは，フォームのMilestone選択とは別に，作成後にGitHubのIssue画面右側にあるMilestone欄へ同じ値を設定してください．** フォームの回答欄だけではGitHub上のMilestoneは設定されません．作成・編集・Milestone設定／解除時にGitHub Actionsが実際の設定値を検査し，未設定またはlec06～lec14以外なら失敗を表示します．Issue Formからの作成自体は停止できないため，失敗を確認したらGitHubのMilestone欄を修正してください．

### スクリプトが確認すること

- 必須の「機能の概要」「AC」があるか
- 担当者が決まっているか
- Milestoneが記入され，GitHub上に存在するか
- 同じタイトルの Issue をすでに登録していないか
- 依存先が実在する open Issue か

### 登録後の確認

登録後は，着手可能な Issue を確認します．

**入力先: ターミナル（Git Bash）**

```bash
bash scripts/issue/ready.sh
```

### 次へ進む前の確認

- GitHub 上に Issue が作成されている．
- Issue に担当者が設定されている．
- Issue にMilestoneが設定されている．
- 各自が自分の Issue の AC を説明できる．

> [!WARNING]
> GitHub Issue が，実装を始める時点での正式な仕様です．要求が変わった場合は，先に Issue の AC・変更境界・実装計画をチームで更新してから実装します．

---

## 5. 実装して Pull Request を作る

### 5-1. ブランチを作る(スクリプト:ready.sh)

担当する Issue 用のブランチを，最新の `origin/main` から作成します．

#### 実施の流れ

1. 作業状態を確認する．
2. `ready.sh` を実行し，着手可能な Issue を確認する．
3. 自分に割り当てられた Issue 番号とブランチ名末尾を入力する．
4. 作成するブランチと起点を確認してから作成する．

#### 実行コマンド

**入力先: ターミナル（Git Bash）**

```bash
git status
bash scripts/issue/ready.sh
```

`ready.sh` は着手可能な Issue を表示します．GitHub 上で自分に割り当てられていることを確認し，Issue 番号とブランチ名末尾を入力します(スクリプトは担当者を変更しません)．作成するブランチと起点を確認すると，その時点の `origin/main` を起点にブランチを作ります．

> [!WARNING]
> `ready.sh` は追跡済みファイルにステージ済みまたは未ステージの変更があると停止します．別の Issue の変更が残っているときは，先にコミットまたは PR 作成を完了させてください．未追跡ファイルはこの検査の対象外です．

#### 次の工程

作成したブランチで，Issue の実装計画を確認します．

### 5-2. AI と実装計画を確認する(スキル:implement-issue)

Issue の範囲とテスト計画を確認し，学生が承認してから実装を始めます．

#### 実施の流れ

1. `implement-issue` Skill を起動する．
2. AI が示す Issue の要約，既存確認，変更予定，テスト計画を読む．
3. Issue 固有の確認や追加の制約がある場合だけ伝える．
4. 計画に納得したら実装開始を承認する．

#### 入力例

**入力先: Copilot Chat**

```text
implement-issue Skill を使って，担当する Issue #12 の実装を始めたいです．
```

Skill は「Issue の要約(AC・依存・変更境界)」「既存確認」「変更予定」「テスト計画」を示し，**「この範囲で実装を始めてよいですか？」と承認を求めます**．基本ルールは Skill が守るため，計画を読んで，Issue 固有の確認や追加の制約がある場合だけ質問・修正します．

#### Issue 固有の確認・制約の入力例

**入力先: Copilot Chat**

```text
既存の Entity を再利用できるか重点的に確認してください．
この Issue では UserController は変更しないでください．
満員の場合に参加できないことを確認するテストを追加してください．
```

納得したら実装を始めるよう伝えます．**AI が作ったコードは，必ず自分で差分を読みましょう．**

### 5-3. テストと動作確認をする

Issue の AC を満たすことを，自動テストと必要に応じたブラウザ操作で確認します．

#### 実施の流れ

1. 差分を確認する．
2. アプリフォルダで自動テストを実行する．
3. Web UI を変更した場合は，アプリを起動して AC に対応する操作をブラウザで確認する．

#### 実行コマンド

**入力先: ターミナル（Git Bash）．`./gradlew` は `app_dir` へ移動してから実行します．**

```bash
git diff
source scripts/lib/project-config.sh
APP_DIR="$(project_app_dir docs/project.md)"
cd "$APP_DIR"
./gradlew test
./gradlew bootRun
```

`./gradlew test` が成功したら，`./gradlew bootRun` を起動したままブラウザで **Issue の AC に対応する操作**を行い，期待する画面・データになることを確認します(例: 満室の AC なら，定員まで参加した後に追加参加を試す)．終了は `Ctrl+C`．

#### 次の工程

テストが失敗した，または AC を満たさない場合は [7. デバッグ](#7-デバッグする) へ進みます．成功した場合は PR 本文を作成します．

### 5-4. PR 本文を作る(プロンプト:/prepare-pr)

AC の確認結果とテスト結果を含む PR 本文の下書きを作成します．この Prompt は PR を作成・pushしません．

#### 実施の流れ

1. `/prepare-pr` を選ぶ．
2. 実装内容，AC ごとの確認結果，`./gradlew test` の結果を順に回答する．
3. 作成された `docs/temp/pr-<Issue番号>.md` を確認する．

#### 入力例

Copilot Chat の入力欄で，`/prepare-pr` を選んでから次のように入力します．

**入力先: Copilot Chat**

```text
/prepare-pr このブランチの PR 本文を作成したいです．
```

この Prompt は，まず「何を実装したか，どこで苦労したか」を聞き，次に AC ごとの確認結果，最後に `./gradlew test` の結果を確認します．

### 5-5. Pull Request を登録する(スクリプト:create-pr.sh)

確認済みの PR 本文，下書き，コミット済みブランチから GitHub Pull Request を作成します．**PRにMilestoneを設定する場合も，そのMilestoneが先にGitHubリポジトリ上で作成されている必要があります．** IssueとPRは同じリポジトリのMilestoneを使います．未作成ならGitHubの **Issues → Milestones → New milestone** で作成してから進んでください．

#### 実施の流れ

1. `docs/temp/pr-<Issue番号>.md` の内容を確認する．
2. 変更をすべてコミットする．
3. リポジトリのルートで登録スクリプトを実行する．
4. 作成された PR を確認し，`/review-pr` でレビューを始める．

#### 実行コマンド

**入力先: ターミナル（Git Bash）**

```bash
cd "$(git rev-parse --show-toplevel)"
bash scripts/pr/create-pr.sh lec06
```

GitHub APIの一時的なエラーでPR作成後のMilestone設定だけが失敗した場合，スクリプトは作成済みPRを確認し，Milestoneの設定を再試行します．同じブランチのOpen PRが既にあれば，新しいPRを作らずMilestoneを確認・修復します．修復できない場合はPR番号と確認方法を表示するので，GitHub上でMilestoneを確認してください．作成済みか不明なときも，GitHub上で同じブランチのPRを確認してから再実行してください．

引数に関連Issueと同じMilestoneを必ず指定します．空欄，GitHub上に存在しない値，Issue側と一致しない値なら，push・PR作成前に停止します．本文・ブランチ・Issue を検査して問題がなければ push と PR 作成を行います．

#### 登録後の確認

- コードとテストの差分を自分で説明できる．
- `./gradlew test` が成功している．
- Web UI を変更した場合は `./gradlew bootRun` で AC を確認した．
- PR 本文に関連 Issue，変更内容，AC 確認結果，テスト結果がある．
- PRに関連Issueと同じMilestoneが設定されている．

---

## 6. レビューしてマージする(プロンプト:/review-pr)

レビューは**実装した本人以外**が行います．「コードに問題がなさそうか」ではなく「**Issue の AC を満たすか**」を確認します．

### 実施の流れ

1. Copilot Chat で `/review-pr` を選ぶ．
2. 表示された Open PR から対象を選ぶ．
3. Issue の AC，PR 本文，差分，テスト，CI を順に確認する．
4. AI が整理したコメント案を確認し，投稿するかを選ぶ．

### 入力例

**入力先: Copilot Chat**

```text
/review-pr
```

### 補助コマンド

確認には GitHub CLI も使えます．

**入力先: ターミナル（Git Bash）**

```bash
gh pr list
gh pr view 12
gh pr diff 12
gh pr checks 12
```

### コメント例

気付いた点は**根拠とともに**書きます．

**入力先: GitHubのPRコメント欄．AIに下書きを依頼する場合はCopilot Chat．**

```text
AC 2 の「満室なら参加できない」について，PR 本文から確認方法と結果を読み取れません．
満室時にどのように確認し，どの結果になったかを PR 本文に追記してください．
```

AI は確認結果を「必須（マージ前に対応が必要）」「質問（事実や判断の確認が必要）」「提案（任意で改善できる点）」に分類し，PR コメントの下書きを示します．学生は下書きの内容を確認し，投稿してよいと判断した場合だけ，AI の投稿可否の質問に「投稿してください」と答えましょう．投稿しない場合や内容を直したい場合は，PR を開いて学生自身がコメントします．

### マージする前の確認

- Issue のすべての AC に対して確認結果がある．
- PR 本文の必須項目が埋まっている．
- CI が成功している．
- 著者以外の学生がレビューし，承認している．

> [!WARNING]
> 「AI が問題ないと言った」ことは承認の根拠になりません．レビュー担当者が差分と必要な動作を確認し，根拠を PR に残してください．

---

## 7. デバッグする(スキル:debug)

テスト失敗や期待と異なる動作が出たら，すぐに「直して」と依頼せず，**再現できる事実**と**原因の予想**を分けて確認しましょう．原因が分かれば，修正範囲と再発防止テストを提案してもらい，納得してから修正を依頼するようにしましょう．不用意に「直して」と依頼すると，修正の根拠が残らず，後で同じ失敗があった際に再現/修正できなくなります．

### 実施の流れ

1. 実行したコマンド，期待した結果，実際の結果，エラー全文を用意する．
2. `debug` Skill を使い，修正前に原因候補を調べる．
3. 原因候補を確認する手順を実行する．
4. 原因，修正範囲，再発防止テストの提案を確認し，納得してから修正を承認する．
5. テストと影響する AC の動作確認をやり直す．

### 入力例

**入力先: Copilot Chat**

```text
debug Skill を使ってください．
Issue #12 の AC は「満室なら追加参加できない」ですが，./gradlew test で次の失敗が出ました: (エラー全文を貼る)
```

Skill は「期待結果／実際の結果／再現手順／原因候補／候補を区別する確認」を分けて示します．コードを変更する前に，原因，修正範囲，再発防止テストを確認し，承認してから修正を依頼しましょう．

### 原因を確認した後の入力例

**入力先: Copilot Chat**

```text
候補 2 を確認し，原因は参加人数の判定が保存前の値を使っていることだと分かりました．
この原因，修正範囲，再発防止テストで修正を進めてください．
```

### 終了前の確認

- 失敗を再現できた，または再現できない理由を説明できる．
- 修正の理由を説明できる．
- 同じ失敗を防ぐ回帰テストがある．
- `./gradlew test` と影響する AC の確認をやり直した．

### 残すもの

修正コード，回帰テスト，修正 PR．AI が記録を残すか尋ねます．残すと学生が答えた場合だけ `docs/trouble/troubleshooting-<GitHubユーザー名>-YYYY-MM-DDTHHMMSS+0900.md` を作り，修正 PR に含めます(時刻は JST，コロンは使わない)．

---

## 8. 毎週の振り返り

進捗の根拠は GitHub Issue と PR です．授業前に，担当した Issue，作成・レビューした PR，AC の確認結果，失敗と改善を振り返ります．

### 実施の流れ

1. 集計スクリプトを実行する．
2. ブラウザで生成された振り返りを確認する．
3. Close済み担当PRごとのAI利用と，週次振り返り用DoDの6項目について自己評価を入力する．DoDは各項目のドロップダウンから回答を一つ選ぶ．必要に応じて別のMilestoneの JSON を選ぶ．

### 実行コマンド

**入力先: ターミナル（Git Bash）**

```bash
# ログイン中の学生について，lec06に属するIssue・PRを集計する
bash scripts/report/weekly-summary.sh --milestone lec06

# 別のMilestoneを集計する
bash scripts/report/weekly-summary.sh --milestone lec07
```

`--milestone` は必須で，`lec06`～`lec14` のGitHub上に存在するMilestoneを指定します．

### 警告・エラーが出た場合

- **引数で指定したMilestoneがGitHub上にない場合**: 作成方法を案内して集計を停止します．GitHubの **Issues → Milestones → New milestone** で作成してから，同じコマンドを再実行してください．
- **Milestone未割当のIssue・PRがある場合**: 指定したMilestone以外のものも含め，番号とURLを表示して集計を停止します．GitHub上で該当Issue・PRにMilestoneを設定し，同じコマンドを再実行してください．既存のJSON・HTMLは差し替えず，バックアップも作りません．
- **複数のassigneeが設定されたIssue・PRがある場合**: 対象とassigneeを表示して集計を停止します．GitHub上で内容を一番よく理解している主担当だけを残し，同じコマンドを再実行してください．この場合，既存のJSON・HTMLは差し替えず，バックアップも作りません．

PR・Issue・コミットの取得に失敗した場合も集計を停止し，既存のJSON・HTMLを差し替えず，バックアップも作りません．

### 出力物と確認

対象学生ごとに `docs/weekly-summary_<GitHubユーザー名>.html` と `docs/weekly-summary-data/<ユーザー名>/lecXX.json` ができ，ブラウザで開きます．同じMilestoneを再集計すると，既存JSONを `lecXX.backup-YYYY-MM-DD_HHMMSS.json.bak` に保存してから新しいJSONに差し替えます．**HTML は閲覧用，JSON が進捗の正本**です．個人のローカル記録で Git 管理しません．

現在ログイン中のGitHubユーザーを対象にします．日時による絞り込みは行いません．担当PRは，assigneeが設定されていれば自分がassigneeであるPR，未設定なら自分が作成したPRです．前回入力したAI利用は同じClose済み担当PRについて引き継ぎ，DoD自己評価は対象Issue・PRの集合が変わらない場合に引き継ぎます．以前の形式のJSONから回答は引き継ぎません．

ページ上部の「表示する記録」でMilestone別の JSON を切り替えられます．全体概要の「概要をコピー」は，Googleスプレッドシートに貼り付けられるタブ区切りテキストをコピーします．学生ごとに1つのスプレッドシートを用意し，lec06から順に最終行の下へ貼り付けてください．各Milestoneの先頭に9つの数値集計行，次にPR・Issueの明細，最後に独立したDoD自己評価6行が入ります．明細の「所要時間」列は「作成日時」の直前にあり，算定できたClose済み担当PRに表示します．行種別「集計」とMilestoneで絞り込めるため，明細の行数が変わっても件数を分析できます．同じMilestoneを再集計して貼り直す場合は，古いMilestoneの行を削除してから貼り付けてください．全体概要ではOpen PR・Open Issueの件数をtrouble reportの後に表示します．Close済み担当PRの下には関連Issueと現在のOpen／Closedを表示し，所要時間には「ブランチ作成からマージまで」のように算定範囲も併記します．ブランチ作成日時が取得できない場合は，最初のコミット，Issue作成，PR作成の順に開始日時を選びます．未マージのPRはClose日時を終了日時とします．DoD自己評価とClose済み担当PRごとのAI利用は，選択内容が表示中の JSON に保存されます．未完了エリアにはMilestoneや担当者を問わず全Open PR・Issueを表示します．コミットは自分が作成した対象MilestoneのPRのもの，コメントは対象Issue・PRに付いたものを集計します．Milestoneに紐付かないローカルのtrouble reportは集計対象外です．最後の通信から約 5 分後にローカルサーバは終了します．新しい週次レポートサーバを起動すると，前のサーバは終了します．

詳細表示はClose済み担当PR，自分がマージしたPR，手動でCloseされたIssue，コミット，GitHubコメント，trouble reportの順です．PR・Issueには主担当，作成者，作成日時など，コピーする明細と同じ項目を表示し，関連Issueにも作成者や日時を表示します．ページ末尾の未完了エリアでは，全Open PR・Issueの担当者，作成者，作成日時，関連Issue・PRを確認できます．

Issue・PRのGitHubリンクにマウスを重ねると，本文やコメント・レビューをローカルのオーバーレイで確認できます．同じリンクの内容はサーバ稼働中に再利用し，サーバ終了時にメモリから全件破棄します．リンクをクリックするとGitHubの元ページを開けます．DoD自己評価の対象リンクは `Issue#5`，`PR#8` のように種類を表示します．

### 過去の記録を開くコマンド

**入力先: ターミナル（Git Bash）**

```bash
bash scripts/report/open-weekly-summary.sh
bash scripts/report/open-weekly-summary.sh --student fukuyasu
bash scripts/report/open-weekly-summary.sh docs/weekly-summary-data/fukuyasu/lec06.json
```

### 振り返る観点

- 指定Milestoneで実装した内容と対応する Issue・PR
- デモで見せる操作と結果
- 自分が理解できたこと，まだ説明できないこと
- AI の使い方，Skill，プロンプト，ハーネスで次週に改善すること

---

## 9. 困ったときの早見表

### 困ったことと最初に行うこと

| 困ったこと | 最初に行うこと | 入力先・操作場所 |
| --- | --- | --- |
| 配布テンプレートを使い始めたい | `/init-project` | Copilot Chat |
| 何を作るかが曖昧 | `/brainstorm` | Copilot Chat |
| 機能をどう分けるか迷う | `/plan-issues` | Copilot Chat |
| MilestoneがGitHubにない | Issues → Milestones → New milestone | GitHubの画面 |
| Issue を GitHub に登録したい | `bash scripts/issue/register-from-file.sh docs/temp/issues.md` | ターミナル（Git Bash） |
| 次に着手できる Issue を知りたい | `bash scripts/issue/ready.sh` | ターミナル（Git Bash） |
| 実装の進め方を確認したい | `implement-issue` Skill | Copilot Chat |
| PR 本文を作りたい | `/prepare-pr` | Copilot Chat |
| PRを登録したい | `bash scripts/pr/create-pr.sh lec06` | ターミナル（Git Bash） |
| レビューしたい | `/review-pr` | Copilot Chat |
| テストが失敗した | `debug` Skill | Copilot Chat |


### プロンプト，スキル，スクリプトごとの入力例

| 対象 | 見出し | 入力例／実行例 | 入力先・操作場所 |
| --- | --- | --- | --- |
| 初期化 | 実施の流れ／入力例／初期化後の確認 | `/init-project` | Copilot Chat |
| ブレインストーミング | 実施の流れ／入力例／次へ進む前の確認 | `/brainstorm <相談したい内容>` | Copilot Chat |
| Issue 分割 | 実施の流れ／入力例／次へ進む前の確認 | `/plan-issues <機能の説明またはブリーフのパス>` | Copilot Chat |
| Issue 登録 | 実施の流れ／実行コマンド／登録後の確認 | `bash scripts/issue/register-from-file.sh docs/temp/issues.md` | ターミナル（Git Bash） |
| ブランチ作成 | 実施の流れ／実行コマンド／次の工程 | `bash scripts/issue/ready.sh` | ターミナル（Git Bash） |
| 実装計画 | 実施の流れ／入力例／承認後の作業 | `implement-issue Skill を使って…` | Copilot Chat |
| テストと動作確認 | 実施の流れ／実行コマンド／確認できた状態 | `app_dir` のフォルダで `./gradlew test`，`./gradlew bootRun` | ターミナル（Git Bash） |
| PR 本文作成 | 実施の流れ／入力例／次の工程 | `/prepare-pr このブランチの PR 本文を作成したいです．` | Copilot Chat |
| PR 登録 | 実施の流れ／実行コマンド／登録後の確認 | `bash scripts/pr/create-pr.sh lec06` | ターミナル（Git Bash） |
| レビュー | 実施の流れ／入力例／マージ前の確認 | `/review-pr` | Copilot Chat |
| デバッグ | 実施の流れ／入力例／終了前の確認 | `debug Skill を使ってください．` | Copilot Chat |
| 週次振り返り | 実施の流れ／実行コマンド／出力物 | `bash scripts/report/weekly-summary.sh --milestone lec06` | ターミナル（Git Bash） |
| テンプレート設定の更新 | 実施の流れ／実行コマンド／更新後の確認 | `bash scripts/harness/generate-template-harness.sh` | ターミナル（Git Bash） |

---

## 付録: ハーネスについて


**全体設計**

- この構成は，巨大な仕様書を先に完成させるのではなく，Issue ごとの小さな仕様(AC)を実装・検証・レビューへつなげる**軽量な Spec-Driven Development** です．
- 学生の達成度は「AI の提案を採用したか」ではなく，**自分たちの判断を説明できるか**で確認することを前提としています
- AI に要約を頼む場合も，Issue・PR・テスト結果を根拠として渡します．振り返りは各自の言葉で書くこと

---

## このプロジェクトにおけるハーネス

このプロジェクトでは，開発手順を支える仕組みをハーネスと呼びます．ハーネスには，機械的に実行・検査・拒否する**決定的ハーネス**と，AI の対話や作業手順を指示する**推論的ハーネス**があります．

### 決定的ハーネス

決定的ハーネスは，スクリプト，GitHub Actions，GitHub リポジトリ設定として実装されています．条件に合わない場合は，エラーで停止するか，実行結果を status check として返します．

| ハーネス | 具体的な実現方法 | 機械的に実行・検査する内容 |
| --- | --- | --- |
| Issue 草案の構造表示 | `.github/prompts/plan-issues.prompt.md` に埋め込まれた PortableGit の `grep` コマンド | `docs/temp/issues.md` の Issue ブロック数，AC 見出し数，実装計画見出し数を数える．開始条件に関する記載箇所と行末空白を表示する．この処理は独立したスクリプトではない． |
| Issue 本文の形式検査 | `scripts/lib/markdown-format.sh` を `scripts/issue/register-from-file.sh` が読み込む | 必須見出しが各1回あること，必須本文が空でないこと，草案 ID・題名が重複しないことを検査する． |
| Issue 登録 | `scripts/issue/register-from-file.sh` | 担当者と既存Milestoneの記入，依存先 Issue の存在と Open 状態を検査する．成功時は Milestone付きで Issue を作成し，依存関係を設定する． |
| GitHub上のIssue Milestone検査 | `.github/workflows/validate-issue-milestone.yml`，`scripts/issue/validate-milestone.sh` | Issue作成後などにGitHub上のMilestoneを取得し，lec06～lec14以外ならActionを失敗させる．Issue Formの本文選択だけでは合格しない． |
| 着手可能 Issue とブランチ作成 | `scripts/issue/ready.sh` | `git diff` と `git diff --cached` で追跡済みの変更を検査する．`gh issue view` で Issue の Open 状態，Open な依存 Issue，担当者を確認する．成功時は `git fetch origin main` と `git switch -c <branch> origin/main` を実行する． |
| PR 本文の形式・関連 Issue 検査 | `scripts/pr/validate-body.sh` | PR 本文の必須見出し・必須本文を検査する．`--check-related-issues` 使用時は，関連 Issue の存在，Issue であること，`Closes` の対象が Open であることを GitHub API で検査する． |
| PR 登録 | `scripts/pr/create-pr.sh` | ブランチ名，追跡済みの未コミット変更，PR 本文ファイル，関連 Issue，既存Milestoneとの一致を検査する．成功時は `git push` と Milestone付きの `gh pr create` を実行する． |
| PR 本文の GitHub 側検査 | `.github/workflows/validate-pr-body.yml` | `pull_request_target` で default branch 側の `scripts/pr/validate-body.sh --stdin --check-related-issues` を実行する．PR 側の検査スクリプトは実行しない． |
| 初期化 | `scripts/harness/init-project.sh` | SSH remote，GitHub CLI 認証，Collaborator 一覧，Spring Bootアプリの自動検出，Gradleテストを検査し，`repository_name`・`app_name`・`app_dir` と開発者一覧を更新する．Collaborator が0人なら停止し，main 保護設定が確認できない場合は警告する． |
| 自動テスト | `.github/workflows/ci.yml` | Pull Request 作成時と `main` への push 時に，`docs/project.md` の `app_dir` を読み，そのフォルダで `./gradlew test` を実行する． |
| テンプレート同期 | `scripts/harness/generate-template-harness.sh` | `docs/template-constraints.md` の `HARNESS-CONFIG` から，Issue Form，PR テンプレート，PR 本文検査 Action，`scripts/lib/markdown-format.sh` を生成する． |
| 週次振り返りの集計 | `scripts/report/weekly-summary.sh`，`scripts/report/weekly-summary-ui.js`，`scripts/report/server-weekly-summary.ps1` | 既存Milestoneを指定し，未割当または複数assigneeのIssue・PRがあれば集計を停止する．Milestone別JSONをバックアップして差し替え，閲覧用HTMLとスプレッドシート貼り付け用のタブ区切り概要を生成する．DoD自己評価とClose済み担当PRごとのAI利用をJSONへ保存する． |

### GitHub リポジトリ設定による main ブランチ保護

分類: 決定的ハーネス（GitHub リポジトリ設定）

- Pull Request を必須にする．
- 学生を bypass list に追加しない．
- force push を許可しない．
- ブランチ削除を許可しない．
- `CI` と `Validate pull request body`
  - これらのstatus checkは必須のほうが望ましいですが，授業では必須とはしません．
  - `ci.yml` と `validate-pr-body.yml` は検査ジョブを実行します．これらを main へのマージ条件にするには，GitHub リポジトリ設定で必須 status check として指定する必要があります．

以上のハーネスを利用するため，GitHub のリポジトリ設定で，default branch の `main` を対象とする Ruleset または Branch protection rule を有効にします．この設定はリポジトリ内のファイルではなく，GitHub のリポジトリ設定で管理します．

#### GitHub Rulesets の設定手順
GitHubの Rulesets（ルールセット） を使って，ブランチへの直接プッシュを禁止し，Pull Request（PR）の作成を必須にする設定手順は以下の通りです． [1] (https://zenn.dev/kimmaru/articles/5dc58050d8e6ad), [2] (https://zenn.dev/justhiro/articles/ced22b2ee42a4d)

- 設定手順

1. 対象のリポジトリを開き，上部のメニューから [Settings] をクリックします(リポジトリ作成者のみ実施可能)． [1] (https://laboratory.kiyono-co.jp/3626/uncategorized/), [2] (https://zenn.dev/kimmaru/articles/5dc58050d8e6ad)
2. 左側のサイドバーにある [Rules] ＞ [Rulesets] を選択します． [1] (https://laboratory.kiyono-co.jp/3626/uncategorized/)
3. 右上の [New ruleset] ＞ [New branch ruleset] をクリックします． [1] (https://zenn.dev/kimmaru/articles/5dc58050d8e6ad), [2] (https://laboratory.kiyono-co.jp/3626/uncategorized/)
4. General（全般） の項目を設定します：
	• Rule name: ルール名を入力する（例: main-protection など）．
	• Enforcement status: [Active] を選択する． [1] (https://laboratory.kiyono-co.jp/3626/uncategorized/), [2] (https://zenn.dev/kimmaru/articles/5dc58050d8e6ad)
5. Target branches（対象ブランチ） を設定します：
	• Add target をクリックし，Include default branch を指定します． [1] (https://nealle-dev.hatenablog.com/entry/2026/07/28/114424), [2] (https://zenn.dev/kimmaru/articles/5dc58050d8e6ad)
6. Rules（適用するルール） の一覧からチェックを入れます：
	• [Require a pull request before merging] にチェックを入れる（必須）．
	• 以下もチェックを入れましょう：
		• [Block force pushes]（強制プッシュの禁止）
		• [Restrict deletions]（ブランチ削除の禁止） [1] (https://docs.github.com/ja/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets), [2] (https://zenn.dev/kimmaru/articles/5dc58050d8e6ad), [3] (https://zenn.dev/justhiro/articles/ced22b2ee42a4d), [4] (https://laboratory.kiyono-co.jp/3626/uncategorized/)
7. 画面一番下の [Create] をクリックして保存します．

• GitHubドキュメント（ルールセットで使用できるルール） で詳細なルール一覧を確認できます． [1] (https://docs.github.com/ja/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets), [2] (https://qiita.com/wakinoza/items/3f49609526a612bfbfb7), [3] (https://zenn.dev/kimmaru/articles/5dc58050d8e6ad)


### 推論的ハーネス

推論的ハーネスは，Prompt，Skill，`AGENTS.md`，instructions ファイルとして実装されています．AI に対して，対話の順序，確認対象，停止条件，作業範囲を指示します．

| ハーネス | 具体的な実現方法 | AI に指示する内容 |
| --- | --- | --- |
| 初期化 | `.github/prompts/init-project.prompt.md` | 初期化スクリプトの実行，Collaborator を含む結果の報告，プロジェクト設定と開発者一覧の更新承認，初期コミット後の `/brainstorm` 案内を指示する． |
| ブレインストーミング | `.github/prompts/brainstorm.prompt.md` | `app_dir` が設定済みか確認し，最初の質問を最大5件にする．明示指示前はファイルを作らず，明示指示後は `docs/temp/brainstorm/` に決められた見出しのブリーフを作る． |
| Issue 分割 | `.github/prompts/plan-issues.prompt.md` | 分割相談と草案作成を2段階で進める．草案作成時は `assignee:` を空欄にし，学生が直接記入するよう案内する． |
| 実装 | `AGENTS.md`，`.github/skills/implement-issue/SKILL.md`，`.github/copilot-instructions.md` | Issue の AC・依存関係・変更境界・既存テストを確認し，変更予定とテスト計画を示してから承認を待つ．必要時だけ `docs/ref/springboot_samples/` を読み取り専用で参照する． |
| Java とテスト | `.github/instructions/java.instructions.md`，`.github/instructions/test.instructions.md` | Java の配置・責務分割，AC に対応するテスト，必要な失敗例・境界値，テスト名の書き方を指示する． |
| PR 本文作成 | `.github/prompts/prepare-pr.prompt.md` | 実装内容，AC ごとの確認結果，テスト結果を段階的に質問し，`docs/temp/pr-<Issue番号>.md` を作る． |
| レビュー | `.github/prompts/review-pr.prompt.md` | Open PR の選択，AC・差分・PR 本文・テスト・CI の確認順，コメント分類，明示承認後だけのコメント投稿を指示する． |
| デバッグ | `.github/skills/debug/SKILL.md` | 期待結果・実際の結果・再現手順を整理し，原因候補と確認方法を提示する．承認後に修正と回帰確認を行い，選択時だけ `docs/trouble/` に記録を作る． |
