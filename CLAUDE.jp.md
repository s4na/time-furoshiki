# CLAUDE.md - Claude Code用指示書

このドキュメントには、time-furoshiki gemで作業する際のClaude Code用の重要な指示が含まれています。

## 重要: READMEの同期

**README.mdを更新する際は、必ずREADME.jp.mdも更新して、両バージョンを同期させてください。**

README.jp.mdは日本語版のドキュメントであり、README.mdと同じ構造と内容を維持しつつ、日本語に翻訳する必要があります。

### README更新の手順:

1. README.mdに変更を加える
2. README.jp.mdに同じ構造的変更を適用する
3. 日本語訳が正確で自然であることを確認する
4. 両ファイルを一緒にコミットする

## プロジェクト概要

time-furoshikiは以下の機能を持つRails gemです：
- マイグレーション実行時にマイグレーションファイルの内容をデータベーステーブルに保存
- ロールバック操作に保存されたマイグレーションを使用
- オリジナルのマイグレーションファイルが変更または削除されてもロールバックが動作することを保証

## 開発ガイドライン

### テスト
変更をコミットする前に、必ず以下を実行してください：
```bash
bundle exec rspec
bundle exec rubocop
```

### CI/CD
- GitHub ActionsがRuby 3.2、3.3、2.7（ベストエフォート）でテストを実行
- マージ前にすべてのテストが合格する必要があります
- RuboCop違反は修正する必要があります

### バージョンサポート
- Ruby: 2.7、3.0、3.1、3.2、3.3
- Rails: 6.0、6.1、7.0、7.1、7.2
- 注：Ruby 3.1はRails 8.0との非互換性のためCIから除外されています

### コードスタイル
- 既存のコード規約に従う
- スタイルチェックにRuboCopを使用
- 行の長さは120文字以下に保つ
- すべてのRubyファイルにfrozen_string_literalコメントを追加

## 一般的なタスク

### テストの実行
```bash
# すべてのテスト
bundle exec rspec

# カバレッジ付き
COVERAGE=true bundle exec rspec

# 特定のファイル
bundle exec rspec spec/time_furoshiki/migration_storage_spec.rb
```

### リンティング
```bash
# 違反のチェック
bundle exec rubocop

# 違反の自動修正
bundle exec rubocop -a
```

### Gemのビルド
```bash
gem build time-furoshiki.gemspec
```

## ファイル構造

```
time-furoshiki/
├── lib/
│   ├── time_furoshiki.rb              # メインモジュール
│   ├── time_furoshiki/
│   │   ├── version.rb                 # バージョン定数
│   │   ├── configuration.rb           # 設定クラス
│   │   ├── migration_storage.rb       # コアストレージロジック
│   │   ├── rails_hooks.rb            # Rails統合
│   │   └── railtie.rb                # Railsエンジン
│   └── time/
│       └── furoshiki.rb              # 後方互換性
├── spec/                              # テストファイル
├── README.md                          # 英語ドキュメント
├── README.jp.md                       # 日本語ドキュメント（同期を保つこと！）
├── SPEC.md                           # 技術仕様
└── time-furoshiki.gemspec            # Gem仕様
```

## 主要コンポーネント

### MigrationStorage
データベースからのマイグレーション内容の保存と取得を処理します。

### RailsHooks
Railsマイグレーションフレームワークと統合し、保存されたマイグレーションをキャプチャして使用します。

### Configuration
`keep_rolled_back_migrations`や`verbose`などのgem設定オプションを管理します。

## 重要な注意事項

1. **常に両方のREADMEファイルを更新する**: README.mdとREADME.jp.mdは同期を保つ必要があります
2. **コミット前にテストする**: フルテストスイートとリンターを実行
3. **CIステータスを確認する**: GitHub Actionsが合格することを確認
4. **TDDに従う**: まずテストを書き、その後実装
5. **変更を文書化する**: 機能追加時に関連ドキュメントを更新