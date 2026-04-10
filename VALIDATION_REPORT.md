# Commerce Knowledge Graph – Stack Validation Report

**검증 일시**: 2026-04-10
**검증 범위**: 파일 형식 / Docker Compose 구성 / 스키마 완결성 / 실행 검증 스크립트

---

## 1/6 파일 존재 검증

| # | 항목 | 결과 |
|---|------|------|
| 1 | docker-compose.yml 존재 | **PASS** |
| 2 | neo4j-schema.cypher 존재 | **PASS** |
| 3 | postgres-schema.sql 존재 | **PASS** |
| 4 | init-stack.sh 존재 | **PASS** |
| 5 | validate-stack.sh 존재 | **PASS** |

---

## 2/6 Docker Compose 구성 검증

| # | 항목 | 결과 | 상세 |
|---|------|------|------|
| 6 | YAML 문법 유효성 | **PASS** | version "3.9", 유효한 구조 |
| 7 | 서비스 3개 정의 (neo4j, postgres, redis) | **PASS** | neo4j, postgres, redis 모두 정의 |
| 8 | 포트 7474 설정 (Neo4j Browser) | **PASS** | `"7474:7474"` |
| 9 | 포트 7687 설정 (Neo4j Bolt) | **PASS** | `"7687:7687"` |
| 10 | 포트 5432 설정 (PostgreSQL) | **PASS** | `"5432:5432"` |
| 11 | 포트 6379 설정 (Redis) | **PASS** | `"6379:6379"` |
| 12 | 헬스체크 3개 서비스 | **PASS** | neo4j: cypher-shell, postgres: pg_isready, redis: redis-cli ping |
| 13 | 볼륨 마운트 | **PASS** | neo4j_data, neo4j_logs, postgres_data, redis_data + 스키마 파일 바인드 |
| 14 | Neo4j 환경변수 | **PASS** | AUTH, PLUGINS(apoc), heap/pagecache 메모리 |
| 15 | PostgreSQL 환경변수 | **PASS** | USER, PASSWORD, DB 설정 |
| 16 | Redis 명령어 옵션 | **PASS** | appendonly, maxmemory 256mb, LRU 정책 |
| 17 | restart 정책 | **PASS** | 전 서비스 `unless-stopped` |

---

## 3/6 Neo4j 스키마 완결성 검증

### 노드 라벨 (10종)

| # | 라벨 | 고유키 제약 | 인덱스 | 결과 |
|---|------|-----------|--------|------|
| 18 | Product | productId UNIQUE | name, modelNumber | **PASS** |
| 19 | Part | partId UNIQUE | name | **PASS** |
| 20 | Symptom | symptomId UNIQUE | keyword | **PASS** |
| 21 | Cause | causeId UNIQUE | keyword | **PASS** |
| 22 | Solution | solutionId UNIQUE | title | **PASS** |
| 23 | Manual | manualId UNIQUE | title | **PASS** |
| 24 | Diagnostic | diagnosticId UNIQUE | code | **PASS** |
| 25 | DocumentType | name UNIQUE | – | **PASS** |
| 26 | Category | name UNIQUE | name | **PASS** |
| 27 | Status | name UNIQUE | – | **PASS** |

**Uniqueness Constraints**: 10개 | **Indexes**: 9개

### 엣지 타입 (9종)

| # | 엣지 | 방향 | 주요 속성 | 결과 |
|---|------|------|----------|------|
| 28 | HAS_PART | Product → Part | quantity, required | **PASS** |
| 29 | HAS_SYMPTOM | Product → Symptom | reportedCount, firstReported | **PASS** |
| 30 | HAS_CAUSE | Symptom → Cause | probability | **PASS** |
| 31 | HAS_SOLUTION | Cause → Solution | effectiveness, verifiedAt | **PASS** |
| 32 | DOCUMENTED_IN | Product/Solution → Manual | section, page | **PASS** |
| 33 | BELONGS_TO | Product/Manual → Category | since | **PASS** |
| 34 | RELATES_TO | Product → Product | relationType | **PASS** |
| 35 | CAUSED_BY | Symptom → Part | confidence | **PASS** |
| 36 | REQUIRES | Solution → Part | quantity, optional | **PASS** |

### 초기 데이터

| # | 항목 | 건수 | 결과 |
|---|------|------|------|
| 37 | Status 초기 데이터 | 3건 (active, deprecated, draft) | **PASS** |
| 38 | DocumentType 초기 데이터 | 3건 (사용자매뉴얼, 수리가이드, FAQ) | **PASS** |
| 39 | Category 초기 데이터 | 5건 (가전, 세탁기, 냉장고, TV, 에어컨) | **PASS** |

---

## 4/6 PostgreSQL 스키마 완결성 검증

| # | 항목 | 결과 | 상세 |
|---|------|------|------|
| 40 | pgvector 확장 활성화 | **PASS** | `CREATE EXTENSION IF NOT EXISTS vector` |
| 41 | manuals 테이블 정의 | **PASS** | 12개 컬럼, manual_id UNIQUE |
| 42 | vector_chunks 테이블 정의 | **PASS** | embedding vector(1536), FK→manuals |
| 43 | embedding 컬럼 (vector 1536) | **PASS** | OpenAI text-embedding-ada-002 호환 |
| 44 | IVFFlat 벡터 유사도 인덱스 | **PASS** | cosine ops, lists=100 |
| 45 | search_similar_chunks 함수 | **PASS** | threshold + top-k 코사인 유사도 검색 |
| 46 | updated_at 자동 갱신 트리거 | **PASS** | trg_manuals_updated_at |
| 47 | manuals 보조 인덱스 (3개) | **PASS** | product_id, doc_type, title(GIN) |
| 48 | vector_chunks 보조 인덱스 (3개) | **PASS** | manual_id, page, metadata(GIN) |

---

## 5/6 초기화 스크립트 검증

| # | 항목 | 결과 | 상세 |
|---|------|------|------|
| 49 | init-stack.sh 실행 가능 | **PASS** | `set -euo pipefail`, bash 스크립트 |
| 50 | docker compose up -d | **PASS** | 분리 모드 기동 |
| 51 | 헬스체크 대기 로직 | **PASS** | neo4j 60s, postgres 30s, redis 20s |
| 52 | Neo4j cypher-shell 스키마 적용 | **PASS** | `-f` 플래그로 스크립트 실행 |
| 53 | PostgreSQL 스키마 자동 적용 | **PASS** | docker-entrypoint-initdb.d 마운트 |
| 54 | validate-stack.sh 구조 | **PASS** | 6단계 검증 + 점수 산출 + 권고사항 |

---

## 6/6 런타임 검증 (실행 필요)

> 아래 항목들은 `./init-stack.sh` 또는 `./validate-stack.sh` 실행 시 자동 검증됩니다.

| # | 항목 | 검증 방법 |
|---|------|----------|
| 55 | ckg-neo4j 컨테이너 running + healthy | `docker ps` |
| 56 | ckg-postgres 컨테이너 running + healthy | `docker ps` |
| 57 | ckg-redis 컨테이너 running + healthy | `docker ps` |
| 58 | Neo4j Bolt 7687 포트 포워딩 | `docker port ckg-neo4j 7687` |
| 59 | Neo4j Browser 7474 포트 포워딩 | `docker port ckg-neo4j 7474` |
| 60 | PostgreSQL 5432 포트 포워딩 | `docker port ckg-postgres 5432` |
| 61 | Redis 6379 포트 포워딩 | `docker port ckg-redis 6379` |
| 62 | Neo4j Constraints 적용 (10개) | `SHOW CONSTRAINTS` |
| 63 | Neo4j Indexes 적용 | `SHOW INDEXES` |
| 64 | Neo4j 초기 데이터 (Status 3건) | `MATCH (s:Status) RETURN count(s)` |
| 65 | PostgreSQL manuals 테이블 생성 | `\dt` |
| 66 | PostgreSQL vector_chunks 테이블 생성 | `\dt` |
| 67 | PostgreSQL pgvector 확장 활성 | `\dx` |
| 68 | PostgreSQL 인덱스 생성 (7+개) | `pg_indexes` |
| 69 | Redis PONG 응답 | `redis-cli ping` |

**실행 명령어**:
```bash
chmod +x init-stack.sh validate-stack.sh
./init-stack.sh         # 스택 기동 + 스키마 적용
./validate-stack.sh     # 전체 검증 실행
```

---

## 검증 결과 요약

| 구분 | 항목 수 | PASS | FAIL | WARN |
|------|---------|------|------|------|
| 파일 존재 | 5 | 5 | 0 | 0 |
| Docker Compose 구성 | 12 | 12 | 0 | 0 |
| Neo4j 스키마 | 22 | 22 | 0 | 0 |
| PostgreSQL 스키마 | 9 | 9 | 0 | 0 |
| 초기화 스크립트 | 6 | 6 | 0 | 0 |
| **합계 (정적 검증)** | **54** | **54** | **0** | **0** |

### 전체 평점: **100 / 100** (정적 검증 기준)

> 런타임 검증 15항목은 `./validate-stack.sh` 실행 시 자동 평가됩니다.

---

## 발견된 문제 및 개선안

| # | 구분 | 내용 | 심각도 |
|---|------|------|--------|
| – | – | 정적 검증에서 발견된 문제 없음 | – |

### 향후 개선 권장 사항

1. **Neo4j 비밀번호**: `changeme123` → 환경변수 또는 시크릿 매니저로 관리
2. **PostgreSQL IVFFlat lists**: 데이터량 증가 시 `sqrt(행 수)` 기준으로 재조정
3. **Redis 비밀번호**: 프로덕션 환경에서 `requirepass` 설정 권장
4. **네트워크 격리**: Docker 네트워크를 명시적으로 정의하여 서비스 간 통신 제한

---

## 다음 단계 권고

1. **샘플 데이터 적재**: Neo4j에 Product/Part/Symptom 샘플 노드 + 엣지 생성
2. **벡터 임베딩**: 샘플 매뉴얼 PDF → 청크 분할 → 임베딩 → PostgreSQL 적재
3. **Redis 캐시 전략**: 검색 결과 캐싱 + TTL 정책 수립
4. **통합 검색 API**: 그래프 탐색 + 벡터 유사도 결합 검색 엔드포인트 개발
5. **모니터링**: Prometheus + Grafana 연동으로 DB 상태 모니터링

---

## 접속 정보 요약

| 서비스 | 엔드포인트 | 인증 |
|--------|-----------|------|
| Neo4j Browser | http://localhost:7474 | `neo4j` / `changeme123` |
| Neo4j Bolt | bolt://localhost:7687 | `neo4j` / `changeme123` |
| PostgreSQL | localhost:5432 | DB: `ckg_vectors`, User: `ckg_user`, PW: `ckg_pass` |
| Redis | localhost:6379 | 인증 없음 |

## 적용된 스키마 요약

### Neo4j (그래프 DB)
- **노드**: Product, Part, Symptom, Cause, Solution, Manual, Diagnostic, DocumentType, Category, Status (10종)
- **엣지**: HAS_PART, HAS_SYMPTOM, HAS_CAUSE, HAS_SOLUTION, DOCUMENTED_IN, BELONGS_TO, RELATES_TO, CAUSED_BY, REQUIRES (9종)
- **제약**: 10개 Uniqueness Constraints
- **인덱스**: 9개 속성 인덱스
- **초기 데이터**: Status 3건, DocumentType 3건, Category 5건

### PostgreSQL (벡터 DB)
- **확장**: pgvector
- **테이블**: manuals (메타데이터), vector_chunks (임베딩)
- **벡터**: 1536차원 (OpenAI text-embedding-ada-002 호환)
- **인덱스**: IVFFlat (코사인 유사도) + B-tree 3개 + GIN 2개
- **함수**: search_similar_chunks() (유사도 검색)

### Redis (캐시)
- **영속성**: AOF (appendonly)
- **메모리**: 256MB, allkeys-lru 정책
