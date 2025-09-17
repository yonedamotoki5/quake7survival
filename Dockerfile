# ==============================
# Builder stage (Spring Boot)
# ==============================
FROM eclipse-temurin:21-jdk-jammy AS builder

WORKDIR /app

# Maven wrapper と pom.xml だけ先にコピーして依存関係をキャッシュ
COPY mvnw mvnw.cmd pom.xml ./
COPY .mvn .mvn

# 依存関係をダウンロード（キャッシュ効率向上）
RUN ./mvnw dependency:go-offline -B

# ソースコードをコピー
COPY src src

# ビルド
RUN ./mvnw clean package -DskipTests

# ==============================
# Runtime stage
# ==============================
FROM debian:buster-slim

# 作業ディレクトリ
WORKDIR /app

# アプリ用ユーザ作成
RUN groupadd -r appuser && useradd -r -g appuser appuser

# ビルド済み Jar をコピー
COPY --from=builder /app/target/quake7survival-*.jar app.jar
RUN chown appuser:appuser app.jar

# ==============================
# CloudWatch Agent
# ==============================
# 公式 CloudWatch Agent イメージからファイルをコピー
COPY --from=amazon/cloudwatch-agent:latest /opt/aws/amazon-cloudwatch-agent /opt/aws/amazon-cloudwatch-agent

# CloudWatch 設定ファイルをコピー
COPY cloudwatch/amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ==============================
# Entrypoint スクリプト
# ==============================
COPY --chmod=775 docker/entrypoint /usr/local/bin/entrypoint

# 権限を調整して非 root ユーザに切り替え
USER root

# ポートとヘルスチェック
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Entrypoint で CloudWatch Agent 起動 + アプリ実行
ENTRYPOINT ["/usr/local/bin/entrypoint", "java", "-jar", "app.jar"]
