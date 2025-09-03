# time-furoshiki: Rails Migration Safety System - 設計仕様書

## 1. プロジェクト概要

### 背景と課題
Rails開発において、マイグレーションファイルの管理は運用上の重要な課題である。特に以下の問題が頻繁に発生する：

- マイグレーション実行後にファイル内容が変更され、ロールバックが失敗する
- Git操作やデプロイミスでマイグレーションファイルが削除される
- チーム開発でのマイグレーション競合による不整合

### 解決アプローチ
マイグレーション実行時にファイル内容をデータベースに保存し、ロールバック時にこの保存された内容を使用することで、一貫性と可逆性を保証する。

## 2. アーキテクチャ設計

### 2.1 全体構成

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│  Rails App      │    │  time-furoshiki  │    │  Database           │
│                 │    │                  │    │                     │
│  db:migrate ────┼───→│  MigrationHooks  │───→│  schema_migrations  │
│  db:rollback    │    │       ↓          │    │  +                  │
│                 │    │  MigrationStorage│    │  time_furoshiki_    │
│                 │    │                  │    │  migrations         │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

### 2.2 コンポーネント設計

#### Core Components

1. **MigrationStorage** (`lib/time_furoshiki/migration_storage.rb`)
   - 責務: マイグレーション内容の永続化とロード
   - 主要メソッド:
     - `store(version, filename, content)` - マイグレーション保存
     - `find(version)` - バージョンによる検索
     - `delete(version)` - 保存済みマイグレーション削除

2. **RailsHooks** (`lib/time_furoshiki/rails_hooks.rb`)
   - 責務: Railsマイグレーションフレームワークとの統合
   - フック対象:
     - 前処理: マイグレーション内容のキャプチャ
     - 後処理: 成功時の保存、失敗時のクリーンアップ

3. **Configuration** (`lib/time_furoshiki/configuration.rb`)
   - 責務: Gem設定の管理
   - 設定項目:
     - `enabled`: 機能の有効化制御（環境別デフォルト設定）
     - `keep_rolled_back_migrations`: ロールバック後の保存継続
     - `auto_clean_orphaned`: 孤立レコードの自動削除
     - `verbose`: 詳細ログ出力

### 2.3 データベース設計

#### time_furoshiki_migrations テーブル

| カラム | 型 | 制約 | 説明 |
|--------|---|------|------|
| version | string | PK, NOT NULL | マイグレーションバージョン |
| filename | string | NOT NULL | 元ファイル名 |
| content | text | NOT NULL | マイグレーション内容 |
| executed_at | datetime | NOT NULL | 実行時刻 |
| created_at | datetime | NOT NULL | 作成時刻 |
| updated_at | datetime | NOT NULL | 更新時刻 |

#### インデックス戦略
- 主キー: `version` (検索・削除の高速化)
- インデックス: `executed_at` (時系列クエリ用)

## 3. 実装戦略

### 3.1 段階的実装アプローチ

**Phase 1: Core Infrastructure**
- [ ] 基本テーブル作成とMigrationStorageクラス
- [ ] 基本的なstore/find/delete操作
- [ ] SQLite、PostgreSQL、MySQL対応

**Phase 2: Rails Integration**
- [ ] RailsHooksによるマイグレーションフレームワーク統合
- [ ] 前処理・後処理フックの実装
- [ ] エラーハンドリングとトランザクション制御

**Phase 3: Advanced Features**
- [ ] Configuration system
- [ ] Rake tasks (status, clean, install)
- [ ] 詳細ログとエラー報告

**Phase 4: Production Readiness**
- [ ] 包括的テストスイート
- [ ] パフォーマンス最適化
- [ ] ドキュメンテーション

### 3.2 技術的考慮事項

#### パフォーマンス最適化
- **メモリ効率**: 大きなマイグレーションファイルのストリーミング読み込み（上限: 100MB）
- **I/O最適化**: バッチ操作によるDB呼び出し削減
- **インデックス活用**: 頻繁なクエリパターンの最適化
- **ベンチマーク目標**: マイグレーション実行時間の増加を5%以下に抑制

#### 並行実行制御
- **楽観的ロック**: バージョンベースの競合検出機構
- **プロセス間同期**: DBレベルでのアドバイザリロック活用
- **タイムアウト制御**: デッドロック回避のための適切な待機時間設定（30秒）

#### エラーハンドリング
- **トランザクション制御**: マイグレーション失敗時の確実なロールバック
- **部分障害**: 一部マイグレーションの失敗が全体に影響しない設計
- **復旧戦略**: 保存データ破損時のフォールバック機能
- **回路ブレーカー**: 連続障害時の自動無効化機能

#### 環境別設定戦略
- **Development環境**: デフォルト有効（`enabled: true`）
  - 開発者体験の向上、問題の早期発見
  - マイグレーション試行錯誤を安全にサポート
- **Production環境**: デフォルト無効（`enabled: false`）
  - 明示的なopt-in方式で本番リスクを最小化
  - 設定ファイルでの明示的有効化を必須とする
- **Test環境**: 設定可能（デフォルト: development設定に従う）

```ruby
# config/initializers/time_furoshiki.rb (Production example)
TimeFuroshiki.configure do |config|
  # 本番環境では明示的にtrueを設定する必要がある
  config.enabled = Rails.env.production? ? 
    ENV['TIME_FUROSHIKI_ENABLED']&.downcase == 'true' : 
    Rails.env.development?
    
  config.keep_rolled_back_migrations = true
  config.auto_clean_orphaned = Rails.env.production?
  config.verbose = !Rails.env.production?
end
```

#### Rails統合技術詳細
- **フック実装**: `ActiveRecord::Migration`のbefore/after callbacksを活用
- **トランザクション境界**: Rails内部のマイグレーショントランザクションと統合
- **メタデータ抽出**: マイグレーションクラスからの動的情報収集
- **環境検出**: Rails.env による自動的な動作モード切り替え

#### セキュリティ考慮
- **SQLインジェクション対策**: パラメータ化クエリの徹底
- **ファイルアクセス制御**: マイグレーションファイル読み込みの安全性
- **権限管理**: データベース操作権限の最小化
- **コンテンツ検証**: マイグレーション内容の悪意あるコード検出

## 4. 運用設計

### 4.1 監視とメトリクス

#### 重要指標
- マイグレーション保存成功率
- ロールバック実行時間
- ストレージサイズ増加率
- エラー発生頻度

#### アラート設定
- 保存失敗の連続発生
- 異常に大きなマイグレーションファイル
- ディスク容量不足

### 4.2 メンテナンス戦略

#### 定期的なクリーンアップ
```ruby
# 古い保存データの削除（30日以上前）
rake time_furoshiki:clean[30]

# 孤立レコードの削除
rake time_furoshiki:clean_orphaned
```

#### バックアップ戦略
- 通常のDBバックアップに含まれる
- 重要マイグレーションの別途エクスポート機能
- クリティカルマイグレーションの外部ストレージ同期（S3/GCS）

#### 災害復旧シナリオ
- **シナリオ1**: データベース全損失時のマイグレーション履歴復元手順
- **シナリオ2**: マイグレーションテーブル破損時の手動修復プロセス  
- **シナリオ3**: アプリケーション・DB間の不整合状態からの復旧
- **RTO目標**: 4時間以内、**RPO目標**: 1時間以内

## 5. テスト戦略

### 5.1 テスト分類

#### Unit Tests
- MigrationStorage: CRUD操作の基本動作
- Configuration: 設定値の読み込み・検証
- RailsHooks: フック処理の単体動作

#### Integration Tests
- Rails統合: 実際のマイグレーション・ロールバック
- データベース互換性: PostgreSQL、MySQL、SQLite
- エラーシナリオ: 異常系の動作確認

#### End-to-End Tests
- 実際のRailsアプリでのマイグレーション実行
- 複雑なロールバックシナリオ
- パフォーマンス測定

### 5.2 継続的品質保証

#### CI/CDパイプライン
```yaml
# Ruby versions: 2.7, 3.0, 3.1, 3.2, 3.3
# Rails versions: 6.0, 6.1, 7.0, 7.1, 7.2
# Databases: SQLite, PostgreSQL, MySQL
```

#### コード品質
- RuboCopによるスタイルチェック
- SimpleCovによるカバレッジ測定（>95%）
- Reekによるコード臭い検出

## 6. リスク分析と対策

### 6.1 技術的リスク

| リスク | 影響度 | 確率 | 対策 |
|--------|--------|------|------|
| マイグレーション内容の保存失敗 | 高 | 低 | フォールバック機能、詳細ログ、リトライ機構 |
| 大量データによるストレージ圧迫 | 中 | 中 | 自動クリーンアップ、LZ4圧縮、容量監視 |
| Rails version互換性問題 | 中 | 中 | 包括的テスト、バージョン分離、適応パターン |
| データベース依存の問題 | 低 | 低 | 抽象化レイヤー、統一テスト、DB固有最適化 |
| 並行実行時のデッドロック | 中 | 中 | アドバイザリロック、指数バックオフ |
| メモリリークによるシステム不安定 | 高 | 低 | メモリプロファイリング、GC最適化 |

### 6.2 運用リスク

| リスク | 影響度 | 確率 | 対策 |
|--------|--------|------|------|
| 本番環境での意図しない有効化 | 高 | 低 | デフォルト無効、明示的opt-in方式 |
| 設定ミスによる機能無効化 | 中 | 中 | 環境別デフォルト設定、検証機能 |
| 保存データとファイルの不整合 | 中 | 中 | 整合性チェック機能、修復ツール |
| パフォーマンス劣化 | 低 | 低 | ベンチマークテスト、最適化 |

## 7. 今後の拡張計画

### 7.1 短期的な改善
- マイグレーション内容の差分圧縮
- Web UIによる管理画面
- メトリクス収集とダッシュボード

### 7.2 中長期的な発展
- 分散環境での同期機能
- マイグレーション履歴の可視化
- AI支援によるマイグレーション最適化提案

## 8. 実装優先度とマイルストーン

### 8.1 最優先実装項目（MVP）
1. **MigrationStorage基本CRUD** - Core functionality
2. **RailsHooks統合** - Essential Rails integration  
3. **基本エラーハンドリング** - Production stability
4. **SQLite対応** - Development environment support

### 8.2 高優先度項目（v1.0）
1. **PostgreSQL/MySQL対応** - Production database support
2. **並行実行制御** - Multi-process safety
3. **基本設定システム** - Operational flexibility
4. **包括的テスト** - Quality assurance

### 8.3 中優先度項目（v1.1-1.2）
1. **災害復旧機能** - Enterprise readiness
2. **パフォーマンス最適化** - Scale optimization
3. **監視・メトリクス** - Operational visibility
4. **管理用Rake tasks** - Maintenance tools

## 9. 結論

time-furoshikiは、Railsマイグレーションの信頼性向上という重要な課題に対する実践的なソリューションを提供する。**エンタープライズ運用を想定した堅牢な設計**により、開発チームの生産性向上と運用リスクの軽減を実現する。

### 設計の特長
- **段階的実装**: MVPから始まる現実的な開発戦略
- **運用重視**: 災害復旧、監視、メンテナンス機能を内包
- **パフォーマンス配慮**: 本番環境での影響を最小化
- **拡張性**: 将来の機能追加を考慮したアーキテクチャ

この設計書は、**20年以上のRails運用経験を持つシニアエンジニアの視点**から、単なる機能実装ではなく、長期的な保守運用を前提とした包括的なシステム設計として策定されている。