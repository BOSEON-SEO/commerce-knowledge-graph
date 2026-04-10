#!/usr/bin/env bash
# ============================================================
# Commerce Knowledge Graph – Stack Validation Script
# 파일 형식 / Compose 구성 / 스키마 완결성 / 컨테이너 / 스키마 적용 검증
# ============================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0
WARN=0
REPORT=""

check() {
    local name="$1"
    local result="$2"  # PASS / FAIL / WARN
    local detail="$3"
    if [ "$result" = "PASS" ]; then
        PASS=$((PASS + 1))
        REPORT+="  [PASS] $name"$'\n'
    elif [ "$result" = "WARN" ]; then
        WARN=$((WARN + 1))
        REPORT+="  [WARN] $name – $detail"$'\n'
    else
        FAIL=$((FAIL + 1))
        REPORT+="  [FAIL] $name – $detail"$'\n'
    fi
}

echo "=========================================="
echo "  Commerce Knowledge Graph – 검증 보고서"
echo "=========================================="
echo ""

# ─────────────────────────────────────────────
# 1. 파일 존재 여부
# ─────────────────────────────────────────────
echo "▶ 1/6  파일 존재 검증"
for f in docker-compose.yml neo4j-schema.cypher postgres-schema.sql init-stack.sh; do
    if [ -f "$f" ]; then
        check "$f 존재" "PASS" ""
    else
        check "$f 존재" "FAIL" "파일 없음"
    fi
done

# ─────────────────────────────────────────────
# 2. Docker Compose YAML 검증
# ─────────────────────────────────────────────
echo "▶ 2/6  Docker Compose 구성 검증"

# docker compose config로 YAML 문법 검증
if docker compose config --quiet 2>/dev/null; then
    check "docker-compose.yml YAML 문법" "PASS" ""
else
    check "docker-compose.yml YAML 문법" "FAIL" "docker compose config 실패"
fi

# 서비스 수 확인
svc_count=$(docker compose config --services 2>/dev/null | wc -l)
if [ "$svc_count" -eq 3 ]; then
    check "서비스 3개 정의" "PASS" ""
else
    check "서비스 3개 정의" "FAIL" "${svc_count}개 발견"
fi

# 필수 포트 확인
compose_content=$(cat docker-compose.yml)
for port in 7474 7687 5432 6379; do
    if echo "$compose_content" | grep -q "$port"; then
        check "포트 $port 설정" "PASS" ""
    else
        check "포트 $port 설정" "FAIL" "docker-compose.yml에 미정의"
    fi
done

# 헬스체크 확인
hc_count=$(grep -c "healthcheck" docker-compose.yml)
if [ "$hc_count" -ge 3 ]; then
    check "헬스체크 3개 서비스" "PASS" ""
else
    check "헬스체크 3개 서비스" "FAIL" "${hc_count}개만 발견"
fi

# 볼륨 확인
vol_count=$(grep -c "volumes:" docker-compose.yml)
if [ "$vol_count" -ge 3 ]; then
    check "볼륨 마운트" "PASS" ""
else
    check "볼륨 마운트" "WARN" "일부 서비스에 볼륨 미설정"
fi

# ─────────────────────────────────────────────
# 3. Neo4j 스키마 완결성 검증
# ─────────────────────────────────────────────
echo "▶ 3/6  Neo4j 스키마 완결성 검증"

cypher_content=$(cat neo4j-schema.cypher)

# 노드 라벨 10종 확인
expected_labels=("Product" "Part" "Symptom" "Cause" "Solution" "Manual" "Diagnostic" "DocumentType" "Category" "Status")
label_found=0
for label in "${expected_labels[@]}"; do
    if echo "$cypher_content" | grep -q "$label"; then
        label_found=$((label_found + 1))
    else
        check "노드 라벨 $label" "FAIL" "스키마에 미정의"
    fi
done
if [ "$label_found" -eq 10 ]; then
    check "노드 라벨 10종 전체" "PASS" ""
fi

# 엣지 타입 9종 확인
expected_edges=("HAS_PART" "HAS_SYMPTOM" "HAS_CAUSE" "HAS_SOLUTION" "DOCUMENTED_IN" "BELONGS_TO" "RELATES_TO" "CAUSED_BY" "REQUIRES")
edge_found=0
for edge in "${expected_edges[@]}"; do
    if echo "$cypher_content" | grep -q "$edge"; then
        edge_found=$((edge_found + 1))
    else
        check "엣지 타입 $edge" "FAIL" "스키마에 미정의"
    fi
done
if [ "$edge_found" -eq 9 ]; then
    check "엣지 타입 9종 전체" "PASS" ""
fi

# 제약 조건 수
constraint_count=$(grep -c "CREATE CONSTRAINT" neo4j-schema.cypher)
check "Uniqueness Constraints (${constraint_count}개)" "PASS" ""

# 인덱스 수
index_count=$(grep -c "CREATE INDEX" neo4j-schema.cypher)
check "Indexes (${index_count}개)" "PASS" ""

# ─────────────────────────────────────────────
# 4. PostgreSQL 스키마 완결성 검증
# ─────────────────────────────────────────────
echo "▶ 4/6  PostgreSQL 스키마 완결성 검증"

sql_content=$(cat postgres-schema.sql)

if echo "$sql_content" | grep -q "CREATE EXTENSION.*vector"; then
    check "pgvector 확장" "PASS" ""
else
    check "pgvector 확장" "FAIL" "CREATE EXTENSION vector 미발견"
fi

if echo "$sql_content" | grep -q "CREATE TABLE.*manuals"; then
    check "manuals 테이블" "PASS" ""
else
    check "manuals 테이블" "FAIL" "미정의"
fi

if echo "$sql_content" | grep -q "CREATE TABLE.*vector_chunks"; then
    check "vector_chunks 테이블" "PASS" ""
else
    check "vector_chunks 테이블" "FAIL" "미정의"
fi

if echo "$sql_content" | grep -q "embedding.*vector"; then
    check "embedding 컬럼 (vector)" "PASS" ""
else
    check "embedding 컬럼" "FAIL" "미정의"
fi

if echo "$sql_content" | grep -q "ivfflat"; then
    check "IVFFlat 벡터 인덱스" "PASS" ""
else
    check "IVFFlat 벡터 인덱스" "FAIL" "미정의"
fi

if echo "$sql_content" | grep -q "search_similar_chunks"; then
    check "유사도 검색 함수" "PASS" ""
else
    check "유사도 검색 함수" "FAIL" "미정의"
fi

# ─────────────────────────────────────────────
# 5. 컨테이너 실행 상태 검증
# ─────────────────────────────────────────────
echo "▶ 5/6  컨테이너 실행 상태 검증"

running_containers=$(docker ps --filter "name=ckg-" --format "{{.Names}}:{{.Status}}" 2>/dev/null)

for cname in ckg-neo4j ckg-postgres ckg-redis; do
    cstatus=$(echo "$running_containers" | grep "$cname" || true)
    if echo "$cstatus" | grep -q "Up"; then
        if echo "$cstatus" | grep -q "healthy"; then
            check "$cname running + healthy" "PASS" ""
        else
            check "$cname running" "WARN" "healthy 아님 – $(echo "$cstatus" | cut -d: -f2)"
        fi
    else
        check "$cname running" "FAIL" "컨테이너가 실행 중이지 않음"
    fi
done

# 포트 포워딩 검증
for port_check in "7474:ckg-neo4j" "7687:ckg-neo4j" "5432:ckg-postgres" "6379:ckg-redis"; do
    port=$(echo "$port_check" | cut -d: -f1)
    svc=$(echo "$port_check" | cut -d: -f2)
    port_line=$(docker port "$svc" "$port" 2>/dev/null || true)
    if [ -n "$port_line" ]; then
        check "$svc 포트 $port 포워딩" "PASS" ""
    else
        check "$svc 포트 $port 포워딩" "FAIL" "포트 매핑 없음"
    fi
done

# ─────────────────────────────────────────────
# 6. 스키마 적용 검증 (DB 접속)
# ─────────────────────────────────────────────
echo "▶ 6/6  스키마 적용 검증"

# Neo4j: 제약 조건 확인
neo4j_constraints=$(docker exec ckg-neo4j cypher-shell -u neo4j -p changeme123 "SHOW CONSTRAINTS" 2>/dev/null || echo "CONNECTION_FAILED")
if echo "$neo4j_constraints" | grep -q "CONNECTION_FAILED"; then
    check "Neo4j 접속" "FAIL" "cypher-shell 연결 실패"
else
    check "Neo4j 접속" "PASS" ""
    neo4j_c_count=$(echo "$neo4j_constraints" | grep -c "UNIQUE" 2>/dev/null || echo "0")
    if [ "$neo4j_c_count" -ge 10 ]; then
        check "Neo4j Constraints 적용 (${neo4j_c_count}개)" "PASS" ""
    else
        check "Neo4j Constraints 적용" "WARN" "${neo4j_c_count}개만 확인 (기대 10개)"
    fi
fi

# Neo4j: 인덱스 확인
neo4j_indexes=$(docker exec ckg-neo4j cypher-shell -u neo4j -p changeme123 "SHOW INDEXES" 2>/dev/null || echo "")
if [ -n "$neo4j_indexes" ]; then
    neo4j_i_count=$(echo "$neo4j_indexes" | grep -c "RANGE\|BTREE" 2>/dev/null || echo "0")
    check "Neo4j Indexes 적용" "PASS" ""
fi

# Neo4j: 초기 데이터 확인
neo4j_status=$(docker exec ckg-neo4j cypher-shell -u neo4j -p changeme123 "MATCH (s:Status) RETURN count(s) AS cnt" 2>/dev/null || echo "0")
if echo "$neo4j_status" | grep -q "3"; then
    check "Neo4j 초기 데이터 (Status 3건)" "PASS" ""
else
    check "Neo4j 초기 데이터" "WARN" "Status 노드 확인 필요"
fi

neo4j_labels=$(docker exec ckg-neo4j cypher-shell -u neo4j -p changeme123 "CALL db.labels() YIELD label RETURN collect(label) AS labels" 2>/dev/null || echo "")
if [ -n "$neo4j_labels" ]; then
    check "Neo4j 노드 라벨 존재 확인" "PASS" ""
fi

# PostgreSQL: 테이블 확인
pg_tables=$(docker exec ckg-postgres psql -U ckg_user -d ckg_vectors -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" 2>/dev/null || echo "CONNECTION_FAILED")
if echo "$pg_tables" | grep -q "CONNECTION_FAILED"; then
    check "PostgreSQL 접속" "FAIL" "psql 연결 실패"
else
    check "PostgreSQL 접속" "PASS" ""
    if echo "$pg_tables" | grep -q "manuals"; then
        check "PostgreSQL manuals 테이블 생성" "PASS" ""
    else
        check "PostgreSQL manuals 테이블 생성" "FAIL" "미생성"
    fi
    if echo "$pg_tables" | grep -q "vector_chunks"; then
        check "PostgreSQL vector_chunks 테이블 생성" "PASS" ""
    else
        check "PostgreSQL vector_chunks 테이블 생성" "FAIL" "미생성"
    fi
fi

# PostgreSQL: pgvector 확장 확인
pg_ext=$(docker exec ckg-postgres psql -U ckg_user -d ckg_vectors -t -c "SELECT extname FROM pg_extension WHERE extname='vector'" 2>/dev/null || echo "")
if echo "$pg_ext" | grep -q "vector"; then
    check "PostgreSQL pgvector 확장 활성" "PASS" ""
else
    check "PostgreSQL pgvector 확장 활성" "FAIL" "확장 미활성"
fi

# PostgreSQL: 인덱스 확인
pg_idx=$(docker exec ckg-postgres psql -U ckg_user -d ckg_vectors -t -c "SELECT indexname FROM pg_indexes WHERE schemaname='public'" 2>/dev/null || echo "")
pg_idx_count=$(echo "$pg_idx" | grep -c "idx_" 2>/dev/null || echo "0")
if [ "$pg_idx_count" -ge 5 ]; then
    check "PostgreSQL 인덱스 (${pg_idx_count}개)" "PASS" ""
else
    check "PostgreSQL 인덱스" "WARN" "${pg_idx_count}개만 확인"
fi

# Redis: 연결 확인
redis_ping=$(docker exec ckg-redis redis-cli ping 2>/dev/null || echo "FAIL")
if echo "$redis_ping" | grep -q "PONG"; then
    check "Redis 접속 (PONG)" "PASS" ""
else
    check "Redis 접속" "FAIL" "redis-cli ping 실패"
fi

# ─────────────────────────────────────────────
# 보고서 출력
# ─────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))
if [ "$TOTAL" -eq 0 ]; then
    SCORE=0
else
    SCORE=$(( (PASS * 100) / TOTAL ))
fi

echo ""
echo "=========================================="
echo "  검증 결과 요약"
echo "=========================================="
echo ""
echo "$REPORT"
echo "──────────────────────────────────────────"
echo "  PASS: $PASS  |  WARN: $WARN  |  FAIL: $FAIL  |  총: $TOTAL"
echo "  전체 평점: ${SCORE}/100"
echo "──────────────────────────────────────────"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "✅ 모든 필수 항목 통과!"
else
    echo "⚠️  $FAIL 건의 실패 항목이 있습니다. 위 보고서를 확인하세요."
fi

echo ""
echo "─── 다음 단계 권고 ───"
echo "  1. 샘플 제품/부품/증상 데이터를 Neo4j에 적재"
echo "  2. 샘플 매뉴얼 PDF를 청크+임베딩하여 PostgreSQL에 적재"
echo "  3. Redis 캐시 전략 구현 (검색 결과 캐싱)"
echo "  4. 통합 검색 API 서비스 개발"
echo "=========================================="
