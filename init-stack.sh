#!/usr/bin/env bash
# ============================================================
# Commerce Knowledge Graph – Stack 초기화 스크립트
# Neo4j + PostgreSQL(pgvector) + Redis 기동 및 스키마 적용
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "1/5  Docker Compose 기동"
echo "=================================================="
docker compose up -d

echo ""
echo "=================================================="
echo "2/5  서비스 헬스체크 대기 (최대 60초)"
echo "=================================================="

wait_for_healthy() {
    local container=$1
    local max_wait=$2
    local elapsed=0
    echo -n "  ⏳ $container 대기 중..."
    while [ $elapsed -lt $max_wait ]; do
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")
        if [ "$status" = "healthy" ]; then
            echo " ✅ healthy"
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    echo " ❌ 타임아웃 ($max_wait초)"
    return 1
}

wait_for_healthy ckg-neo4j    60
wait_for_healthy ckg-postgres 30
wait_for_healthy ckg-redis    20

echo ""
echo "=================================================="
echo "3/5  Neo4j 스키마 적용"
echo "=================================================="
docker exec ckg-neo4j cypher-shell \
    -u neo4j -p changeme123 \
    -f /var/lib/neo4j/import/neo4j-schema.cypher

echo "  ✅ Neo4j 스키마 적용 완료"

echo ""
echo "=================================================="
echo "4/5  PostgreSQL 스키마 확인"
echo "=================================================="
# postgres-schema.sql은 docker-entrypoint-initdb.d 에 마운트되어 자동 실행됨
docker exec ckg-postgres psql -U ckg_user -d ckg_vectors -c "\dt" 2>/dev/null
docker exec ckg-postgres psql -U ckg_user -d ckg_vectors -c "\dx" 2>/dev/null
echo "  ✅ PostgreSQL 스키마 확인 완료"

echo ""
echo "=================================================="
echo "5/5  컨테이너 상태 확인"
echo "=================================================="
docker ps --filter "name=ckg-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=================================================="
echo "🎉  스택 초기화 완료!"
echo ""
echo "접속 정보:"
echo "  Neo4j Browser : http://localhost:7474  (neo4j / changeme123)"
echo "  Neo4j Bolt    : bolt://localhost:7687"
echo "  PostgreSQL    : localhost:5432  (ckg_user / ckg_pass / ckg_vectors)"
echo "  Redis         : localhost:6379"
echo "=================================================="
