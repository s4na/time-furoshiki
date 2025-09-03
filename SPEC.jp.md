# time-furoshiki Gem 仕様書

## 概要
time-furoshikiは、マイグレーション実行時にマイグレーションファイルの内容をデータベーステーブルに保存し、ロールバック操作時にこれらの保存されたマイグレーションを使用するRails gemです。

## コア機能

### 1. マイグレーションストレージ
- `rails db:migrate`が実行されると、gemはマイグレーションファイルの内容をキャプチャします
- 専用のデータベーステーブル`time_furoshiki_migrations`にマイグレーションの内容を保存します
- 各保存されたマイグレーションには以下が含まれます：
  - `version`: マイグレーションバージョン/タイムスタンプ（文字列、主キー）
  - `filename`: オリジナルのマイグレーションファイル名（文字列）
  - `content`: 完全なマイグレーションファイルの内容（テキスト）
  - `executed_at`: マイグレーションが実行されたタイムスタンプ（日時）
  - `created_at`: レコード作成タイムスタンプ（日時）
  - `updated_at`: レコード更新タイムスタンプ（日時）

### 2. マイグレーションロールバック
- `rails db:rollback`が実行されると、gemはロールバックプロセスをインターセプトします
- データベースから保存されたマイグレーションの内容を取得します
- 保存された内容を使用してロールバックを実行します（オリジナルファイルが変更または削除されていても）

### 3. データベーステーブル管理
- 最初の使用時に`time_furoshiki_migrations`テーブルを自動的に作成します
- テーブル作成は自動的に実行される組み込みマイグレーションを介して行われます
- テーブル管理用のrakeタスクを提供します：
  - `time_furoshiki:install` - マイグレーションテーブルを作成
  - `time_furoshiki:status` - 保存されたマイグレーションのステータスを表示
  - `time_furoshiki:clean` - 孤立したマイグレーションレコードを削除

## 技術要件

### 互換性
- **Rubyバージョン**: 2.7、3.0、3.1、3.2、3.3
- **Railsバージョン**: 6.0、6.1、7.0、7.1、7.2
- **データベースサポート**: PostgreSQL、MySQL、SQLite

### インストール
Gemfileに追加：
```ruby
gem 'time-furoshiki'
```

実行：
```bash
bundle install
rails generate time_furoshiki:install
rails db:migrate
```

## 実装詳細

### 1. Rails統合
- 以下を介してRailsマイグレーションフレームワークにフックします：
  - `ActiveRecord::Migration`のモンキーパッチまたはプリペンド
  - `ActiveRecord::Migrator`の拡張
- 適切なポイントでマイグレーション実行をインターセプトします

### 2. マイグレーション保存プロセス
```ruby
# マイグレーション実行時：
1. マイグレーション実行前に、マイグレーションファイルの内容をキャプチャ
2. オリジナルのマイグレーションを実行
3. 成功した場合、マイグレーションの内容をデータベースに保存
4. 失敗した場合、保存しない（トランザクションロールバック）
```

### 3. ロールバックプロセス
```ruby
# ロールバック時：
1. time_furoshiki_migrationsにマイグレーション内容が存在するか確認
2. 存在する場合、保存された内容をロールバックに使用
3. 存在しない場合、オリジナルファイルにフォールバック（警告付き）
4. ロールバック成功後、オプションで保存されたレコードを削除
```

### 4. データモデル
```ruby
class TimeFuroshikiMigration < ActiveRecord::Base
  self.table_name = 'time_furoshiki_migrations'
  
  validates :version, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :content, presence: true
  
  scope :executed, -> { order(version: :desc) }
end
```

### 5. 設定
```ruby
# config/initializers/time_furoshiki.rb
TimeFuroshiki.configure do |config|
  # ロールバック後もマイグレーションレコードを保持（デフォルト：true）
  config.keep_rolled_back_migrations = true
  
  # 孤立したレコードを自動クリーン（デフォルト：false）
  config.auto_clean_orphaned = false
  
  # 詳細ログを有効化（デフォルト：false）
  config.verbose = false
end
```

## エラー処理

### マイグレーション保存エラー
- 保存が失敗した場合、警告をログに記録するがマイグレーションは失敗させない
- ログに明確なエラーメッセージを提供

### ロールバックエラー
- 保存されたマイグレーションが見つからない場合、オリジナルファイルの使用を試みる
- 保存されたものもオリジナルも見つからない場合、説明的なエラーで失敗
- すべてのロールバック試行と結果をログに記録

## テスト戦略

### ユニットテスト
- マイグレーション内容のキャプチャをテスト ✅
- 保存と取得操作をテスト ✅
- 保存された内容でのロールバックをテスト ✅
- 設定オプションをテスト ✅

### 統合テスト
- 完全なマイグレーション → 保存 → ロールバックサイクルをテスト ✅
- 異なるRailsバージョンでテスト ✅
- 異なるデータベースアダプタでテスト ✅
- エラーシナリオをテスト ✅

### テストカバレッジ要件
- 最小90%のコードカバレッジ（現在：35.95% - 進行中）
- すべてのパブリックAPIをテストする必要がある ✅
- すべてのエラーパスをテストする必要がある ✅

### テストファイル
- `spec/spec_compliance_test.rb` - 包括的なSPEC.md準拠テスト
- `spec/integration/migration_lifecycle_spec.rb` - マイグレーションライフサイクル統合テスト
- `spec/migration_storage_spec.rb` - MigrationStorageユニットテスト
- `spec/rails_integration_spec.rb` - Rails統合テスト

## セキュリティ考慮事項

### SQLインジェクション防止
- すべてのデータベース操作にパラメータ化クエリを使用
- マイグレーションバージョン入力をサニタイズ

### マイグレーション内容の検証
- 保存/実行前にRuby構文を検証
- 悪意のあるコードの実行を防止

## パフォーマンス考慮事項

### データベースインデックス
- 高速検索のための`version`カラムのインデックス
- ステータスクエリ用の`executed_at`のインデックスを検討

### ストレージ最適化
- 必要に応じて大きなマイグレーション内容を圧縮
- 古いマイグレーションのクリーンアップ戦略を実装

## 将来の拡張機能（MVPには含まれない）
- マイグレーション差分表示
- マイグレーション履歴追跡
- 保存されたマイグレーションを使用した特定バージョンへのロールバック
- マイグレーション内容のバージョニング
- 保存されたマイグレーションを表示するWeb UI