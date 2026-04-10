# Commerce Knowledge Graph

전자제품 커머스의 분산된 지식을 **그래프 + 벡터** 기반으로 통합하고, LLM이 자동 유지보수하며 피드백으로 자가 교정되는 사내 AI 지식베이스 챗봇.

---

## 아키텍처

| 서비스 | 이미지 | 역할 | 포트 |
|--------|--------|------|------|
| **Neo4j 5.x** | `neo4j:5-community` | 지식 그래프 (노드·엣지) | `7474` (Browser), `7687` (Bolt) |
| **PostgreSQL 15** | `pgvector/pgvector:pg15` | 벡터 임베딩 저장·검색 | `5432` |
| **Redis 7** | `redis:7-alpine` | 캐시 / 세션 / 큐 | `6379` |

---

## 빠른 시작

```bash
# 1. 스택 기동 + 스키마 자동 적용
chmod +x init-stack.sh
./init-stack.sh

# 2. 개별 실행 (수동)
docker compose up -d          # 컨테이너 기동
docker compose down            # 컨테이너 중지
docker compose down -v         # 볼륨까지 삭제 (초기화)
```

---

## 접속 정보

| 서비스 | 엔드포인트 | 인증 |
|--------|-----------|------|
| Neo4j Browser | http://localhost:7474 | `neo4j` / `changeme123` |
| Neo4j Bolt | `bolt://localhost:7687` | `neo4j` / `changeme123` |
| PostgreSQL | `localhost:5432` | DB: `ckg_vectors`, User: `ckg_user`, PW: `ckg_pass` |
| Redis | `localhost:6379` | 인증 없음 |

---

## Neo4j 스키마 요약

### 노드 라벨 (10종)

| 라벨 | 주요 속성 | 설명 |
|------|----------|------|
| `Product` | productId, name, modelNumber, brand | 제품 |
| `Part` | partId, name, partNumber, price, availability | 부품 |
| `Symptom` | symptomId, keyword, description, severity | 증상 |
| `Cause` | causeId, keyword, description, frequency | 원인 |
| `Solution` | solutionId, title, steps, difficulty, estimatedTime | 해결책 |
| `Manual` | manualId, title, version, fileUrl, language | 매뉴얼 |
| `Diagnostic` | diagnosticId, code, description, procedure | 진단 |
| `DocumentType` | name, description | 문서 유형 |
| `Category` | name, description, parentName | 카테고리 |
| `Status` | name, description | 상태 |

### 엣지 타입 (9종)

| 엣지 | 방향 | 주요 속성 | 설명 |
|------|------|----------|------|
| `HAS_PART` | Product → Part | quantity, required | 제품-부품 |
| `HAS_SYMPTOM` | Product → Symptom | reportedCount, firstReported | 제품-증상 |
| `HAS_CAUSE` | Symptom → Cause | probability | 증상-원인 |
| `HAS_SOLUTION` | Cause → Solution | effectiveness, verifiedAt | 원인-해결책 |
| `DOCUMENTED_IN` | Product/Solution → Manual | section, page | 문서화 |
| `BELONGS_TO` | Product/Manual → Category | since | 카테고리 소속 |
| `RELATES_TO` | Product → Product | relationType | 제품 간 관계 |
| `CAUSED_BY` | Symptom → Part | confidence | 부품 기인 증상 |
| `REQUIRES` | Solution → Part | quantity, optional | 해결에 필요한 부품 |

### 제약 조건 & 인덱스

- **Uniqueness Constraints**: 모든 노드 라벨의 ID/name 필드에 고유 제약 조건 적용 (10개)
- **Indexes**: name, keyword, code, title, modelNumber 등 검색 빈도가 높은 속성에 인덱스 생성 (9개)
- **초기 데이터**: Status 3건, DocumentType 3건, Category 5건 MERGE

---

## PostgreSQL 스키마 요약

### 테이블

| 테이블 | 설명 |
|--------|------|
| `manuals` | 매뉴얼 메타데이터 (Neo4j Manual 노드와 `manual_id`로 매핑) |
| `vector_chunks` | 문서 청크 + 1536차원 벡터 임베딩 (OpenAI text-embedding-ada-002 기준) |

### 주요 인덱스

| 인덱스 | 테이블 | 타입 | 용도 |
|--------|--------|------|------|
| `idx_manuals_product_id` | manuals | B-tree | 제품별 매뉴얼 조회 |
| `idx_manuals_title` | manuals | GIN (tsvector) | 제목 전문 검색 |
| `idx_chunks_embedding_ivfflat` | vector_chunks | IVFFlat (cosine) | 벡터 유사도 검색 |
| `idx_chunks_metadata` | vector_chunks | GIN (jsonb) | 메타데이터 필터 |

### 유틸리티

- **`search_similar_chunks()`** — 코사인 유사도 기반 벡터 검색 함수 (threshold + top-k)
- **`trg_manuals_updated_at`** — manuals 테이블 `updated_at` 자동 갱신 트리거

---

## 디렉터리 구조

```
commerce-knowledge-graph/
├── docker-compose.yml       # Neo4j + PostgreSQL + Redis 스택 정의
├── neo4j-schema.cypher      # 그래프 스키마 (노드 10종, 엣지 9종)
├── postgres-schema.sql      # 벡터 DB 스키마 (pgvector)
├── init-stack.sh            # 원클릭 초기화 스크립트
└── README.md                # 이 문서
```

---

## 환경 변수 (docker-compose.yml)

| 서비스 | 변수 | 기본값 |
|--------|------|--------|
| Neo4j | `NEO4J_AUTH` | `neo4j/changeme123` |
| Neo4j | `NEO4J_PLUGINS` | `["apoc"]` |
| Neo4j | `NEO4J_dbms_memory_heap_max__size` | `1G` |
| PostgreSQL | `POSTGRES_USER` | `ckg_user` |
| PostgreSQL | `POSTGRES_PASSWORD` | `ckg_pass` |
| PostgreSQL | `POSTGRES_DB` | `ckg_vectors` |
| Redis | maxmemory | `256mb` (LRU 정책) |

---

## 볼륨

| 볼륨 | 마운트 경로 | 용도 |
|------|------------|------|
| `neo4j_data` | `/data` | 그래프 데이터 |
| `neo4j_logs` | `/logs` | Neo4j 로그 |
| `postgres_data` | `/var/lib/postgresql/data` | PostgreSQL 데이터 |
| `redis_data` | `/data` | Redis AOF 데이터 |
