# time-furoshiki

[![CI](https://github.com/yourusername/time-furoshiki/actions/workflows/main.yml/badge.svg)](https://github.com/yourusername/time-furoshiki/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/time-furoshiki.svg)](https://badge.fury.io/rb/time-furoshiki)
[![Code Climate](https://codeclimate.com/github/yourusername/time-furoshiki/badges/gpa.svg)](https://codeclimate.com/github/yourusername/time-furoshiki)

Rails向けのgemで、マイグレーション実行時にマイグレーションファイルの内容をデータベーステーブルに保存し、ロールバック操作時にこれらの保存されたマイグレーションを使用します。これにより、元のマイグレーションファイルが変更または削除された場合でも、ロールバックが常に正しく動作することを保証します。

## 機能

- **自動マイグレーション保存**: `rails db:migrate` 実行時にマイグレーションファイルの内容をキャプチャして保存
- **信頼性の高いロールバック**: ロールバック時に保存されたマイグレーション内容を使用し、一貫性を確保
- **データベース非依存**: PostgreSQL、MySQL、SQLiteで動作
- **Rails統合**: Railsマイグレーションフレームワークとシームレスに統合
- **設定可能**: さまざまなユースケースに対応する柔軟な設定オプション
- **マルチバージョン対応**: Ruby 2.7+およびRails 6.0+と互換性

## インストール

アプリケーションのGemfileに以下の行を追加してください：

```ruby
gem 'time-furoshiki'
```

その後、次のコマンドを実行します：

```bash
$ bundle install
```

または、直接インストールすることもできます：

```bash
$ gem install time-furoshiki
```

インストール後、ジェネレーターを実行して必要なデータベーステーブルを作成します：

```bash
$ rails generate time_furoshiki:install
$ rails db:migrate
```

## 使用方法

インストール後、time-furoshikiは自動的にバックグラウンドで動作します：

### マイグレーションの実行

通常通りマイグレーションを実行すると：

```bash
$ rails db:migrate
```

time-furoshikiは以下の処理を行います：
1. 実行前にマイグレーションファイルの内容をキャプチャ
2. マイグレーションを実行
3. 成功した場合、マイグレーション内容を`time_furoshiki_migrations`テーブルに保存

### マイグレーションのロールバック

マイグレーションをロールバックする際：

```bash
$ rails db:rollback
```

time-furoshikiは以下の処理を行います：
1. データベースに保存されたマイグレーション内容をチェック
2. ロールバックに保存された内容を使用（一貫性を確保）
3. 保存されたバージョンが存在しない場合は、元のファイルにフォールバック

### Rakeタスク

time-furoshikiは管理用のRakeタスクを提供しています：

```bash
# 保存されたマイグレーションのステータスを表示
$ rake time_furoshiki:status

# 孤立したマイグレーションレコードをクリーンアップ
$ rake time_furoshiki:clean

# マイグレーションテーブルを再インストール
$ rake time_furoshiki:install
```

## 設定

初期化ファイル`config/initializers/time_furoshiki.rb`を作成します：

```ruby
TimeFuroshiki.configure do |config|
  # ロールバック後もマイグレーションレコードを保持（デフォルト: true）
  # falseに設定すると、ロールバック成功後に保存されたマイグレーションを自動削除
  config.keep_rolled_back_migrations = true
  
  # 孤立したレコードを自動クリーンアップ（デフォルト: false）
  # trueに設定すると、対応するマイグレーションファイルがないレコードを定期的に削除
  config.auto_clean_orphaned = false
  
  # 詳細ログを有効化（デフォルト: false）
  # trueに設定すると、保存とロールバック操作の詳細なログを出力
  config.verbose = false
end
```

## データベーススキーマ

time-furoshikiは以下の構造の`time_furoshiki_migrations`テーブルを作成します：

| カラム | 型 | 説明 |
|--------|------|-------------|
| `version` | string | マイグレーションバージョン/タイムスタンプ（主キー） |
| `filename` | string | 元のマイグレーションファイル名 |
| `content` | text | マイグレーションファイルの完全な内容 |
| `executed_at` | datetime | マイグレーション実行時刻 |
| `created_at` | datetime | レコード作成タイムスタンプ |
| `updated_at` | datetime | レコード更新タイムスタンプ |

## 動作原理

### マイグレーション保存プロセス

```ruby
# マイグレーション実行時：
1. 実行前 → マイグレーションファイルの内容をキャプチャ
2. マイグレーション実行 → 実際のマイグレーションを実行
3. 成功後 → データベースに内容を保存
4. 失敗時 → トランザクションロールバック（保存しない）
```

### ロールバックプロセス

```ruby
# ロールバック時：
1. データベースをチェック → 保存されたマイグレーション内容を探す
2. 見つかった場合 → ロールバックに保存された内容を使用
3. 見つからない場合 → 警告付きで元のファイルを使用
4. 成功後 → オプションで保存されたレコードを削除
```

## 互換性

| Rubyバージョン | Rails 6.0 | Rails 6.1 | Rails 7.0 | Rails 7.1 | Rails 7.2 |
|--------------|-----------|-----------|-----------|-----------|-----------|
| 2.7          | ✅ | ✅ | ✅ | ✅ | ❌ |
| 3.0          | ✅ | ✅ | ✅ | ✅ | ❌ |
| 3.1          | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3.2          | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3.3          | ✅ | ✅ | ✅ | ✅ | ✅ |

## 開発

リポジトリをチェックアウトした後、`bin/setup`を実行して依存関係をインストールします。次に、`rake spec`を実行してテストを実行します。実験用の対話型プロンプトには`bin/console`を使用できます。

異なるRailsバージョンに対してテストする場合：

```bash
# appraisal gemsetをインストール
$ bundle exec appraisal install

# 特定のRailsバージョンでテストを実行
$ bundle exec appraisal rails-7.0 rspec

# すべてのバージョンでテストを実行
$ bundle exec appraisal rspec
```

このgemをローカルマシンにインストールするには：

```bash
$ bundle exec rake install
```

## テスト

テストスイートを実行：

```bash
# すべてのテストを実行
$ bundle exec rspec

# カバレッジレポート付きで実行
$ COVERAGE=true bundle exec rspec

# 特定のテストファイルを実行
$ bundle exec rspec spec/time_furoshiki/migration_storage_spec.rb

# 異なるデータベースアダプタでテストを実行
$ DATABASE_ADAPTER=postgresql bundle exec rspec
$ DATABASE_ADAPTER=mysql bundle exec rspec
```

## コントリビューション

バグレポートとプルリクエストはGitHub（https://github.com/yourusername/time-furoshiki）で受け付けています。このプロジェクトは、協力のための安全で歓迎される空間であることを意図しており、貢献者は[行動規範](https://github.com/yourusername/time-furoshiki/blob/main/CODE_OF_CONDUCT.md)に従うことが期待されています。

1. フォークする
2. フィーチャーブランチを作成する（`git checkout -b my-new-feature`）
3. 変更をコミットする（`git commit -am 'Add some feature'`）
4. ブランチにプッシュする（`git push origin my-new-feature`）
5. 新しいプルリクエストを作成する

## ライセンス

このgemは[MITライセンス](https://opensource.org/licenses/MIT)の条項の下でオープンソースとして利用可能です。

## 行動規範

time-furoshikiプロジェクトのコードベース、課題トラッカー、チャットルーム、メーリングリストで交流する全ての人は、[行動規範](https://github.com/yourusername/time-furoshiki/blob/main/CODE_OF_CONDUCT.md)に従うことが期待されています。

## 謝辞

「風呂敷（furoshiki）」という名前は、日本の伝統的な包み布を指し、このgemがマイグレーションを「包んで」安全に保管する様子を象徴しています。