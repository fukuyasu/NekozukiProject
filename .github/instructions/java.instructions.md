---
applyTo: "**/src/main/java/**/*.java"
---

# Java / Spring Boot

- `docs/project.md` の `PROJECT-CONFIG` にある `app_dir` のアプリコードと書式に従う。
- 基本的な実装はdocs/ref/springboot_samplesを参照する。
- Controller はHTTP入出力、Service はユースケース、Mapper/Repository は永続化を担当する。
- 入力値、認可、例外時の振る舞いをIssueのACとテストで確認する。
- 自明なコメントは追加せず、コードだけでは分からない意図を日本語で記録する。
