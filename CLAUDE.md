## 프로젝트 개요
전자제품 커머스의 분산된 지식(제품 카탈로그, A/S 매뉴얼, CS 로그, 주문 이력, 가격/이벤트)을 그래프 기반 통합 지식베이스로 구축하고, LLM이 자동 유지보수하며 피드백으로 자가 교정되는 사내 AI 챗봇 시스템.

## 아키텍처 계층
```
Frontend: Next.js (Wiki UI + Chat UI + 인터랙티브 학습소)
  ↓
API Gateway + Auth + Role Middleware
  ↓
App Server (FastAPI on Docker)
  ├─ Query Planner: 자연어 → Cypher + vector query
  ├─ Context Merger: 그래프 결과 + 벡터 결과 통합
  ├─ Answer Synthesizer: LLM 답변 생성 + 출처 명시
  ├─ Schema Layer: 엣지 화이트리스트, role 필터
  └─ Wiki Writer + Lint Agent
  ↓
Neo4j (Graph DB) + PostgreSQL+pgvector + Redis
  ↑
ETL Pipeline (Kafka+Debezium)
```

## 기술 스택
- **Graph DB**: Neo4j (Cypher 쿼리)
- **Vector DB**: PostgreSQL + pgvector (의미 검색)
- **Cache**: Redis (FAQ 캐시, LLM 미호출 경로)
- **Backend**: FastAPI (Python)
- **Frontend**: Next.js
- **LLM**: Ollama (로컬, 기본) + 외부 API 라우팅 (복잡 질문)
- **ETL**: Kafka + Debezium
- **인프라**: Docker Compose

## 핵심 설계 원칙
1. **노드는 평등, 상하관계는 엣지의 한 종류** — 같은 제품이 용도/형태/브랜드/기능 등 여러 관점으로 동시 분류 가능 (faceted edge)
2. **탐색 영역 제한은 홉 수가 아니라 엣지 타입 화이트리스트** — 맥락별 허용 엣지와 차단 노드 라벨을 미들웨어가 자동 적용
3. **벡터는 창고, 그래프가 구조를 안다** — 벡터 검색은 유사 텍스트 탐색만, chunk 정체(어떤 제품의 어떤 섹션)는 그래프 연결이 결정
4. **임베딩 모델과 LLM은 완전히 별개** — 각각 독립 교체 가능, 임베딩 모델은 변경 시 전체 재임베딩 필요하므로 초기 확정 후 유지
5. **LLM 파인튜닝 불필요** — 매 호출 시 시스템 프롬프트에 스키마+도메인 컨텍스트 전달

## 그래프 스키마
### 노드 라벨
| Label | 주요 속성 |
|---|---|
| Product | sku, name, brand, price, status |
| Category | name, facet_type |
| Part | part_number, name, lifespan_months |
| Symptom | description, severity |
| Procedure | title, steps_json, difficulty, est_minutes |
| Document | title, type, source, chunk_ids[] |
| Customer | customer_hash, tier |
| Order | order_id, date, total, status |
| CSTicket | ticket_id, channel, resolved, satisfaction |
| Event | type, start_date, end_date, discount_pct |

### 엣지 타입
| Edge | From → To | 설명 |
|---|---|---|
| BELONGS_TO | Product → Category | 다면 분류 |
| HAS_PART | Product → Part | 구성 부품 |
| CAUSES | Part → Symptom | 부품 고장→증상 |
| FIXES | Procedure → Symptom | 절차→증상 해결 |
| DOCUMENTED_IN | Product → Document | 매뉴얼 연결 |
| PURCHASED | Customer → Product | 구매 이력 |
| REPORTED | Customer → Symptom | 증상 신고 |
| APPLIED_TO | Event → Product | 이벤트 적용 |
| COMPATIBLE_WITH | Product → Product | 호환 제품 |

### 맥락별 엣지 화이트리스트
| 맥락 | 허용 엣지 | 차단 노드 |
|---|---|---|
| PDP | HAS_PART, CAUSES, FIXES, DOCUMENTED_IN, COMPATIBLE_WITH | Customer, Order, CSTicket |
| 고객 챗봇 | PDP + BELONGS_TO | Customer, Order, CSTicket, InternalOnly |
| CS 상담원 | 전체 (고객 이력 포함) | 없음 |
| Admin | 전체 + 통계 | 없음 |

## 벡터 스토어 청킹 규칙
- 단위: 200~500 토큰, 문단 경계 유지
- 대용량 문서: 2단계 처리 (목차 파악 → 섹션별 처리)
- 필수 메타데이터: product_id, document_type(manual/faq/cs_log), section_type(troubleshooting/setup/usage)

## 쿼리 플로우
1. LLM intent 파싱 (0.3~0.5초)
2. Graph traversal: 엣지 화이트리스트 적용 (50~200ms)
3. Vector search: 유사도 검색 + product_id 필터링 (20~100ms)
4. 2+3 병렬 실행 → 결과 통합 정렬
5. LLM 답변 생성 + 출처 명시 (streaming, 0.5초 후 출력)
6. 캐시 히트 시 < 0.1초

## DoD 패턴
- **모든 API 엔드포인트**: 맥락별 엣지 화이트리스트 미들웨어 통과
- **데이터 ingest**: 품질 리포트(중복/버전충돌/불일치) 자동 생성 후 사용자 컨펌 후 저장
- **Good/Bad 피드백**: Bad 수신 시 LLM이 교정안 생성 → 담당자 컨펌 → 그래프 즉시 업데이트
- **할루시네이션 방지**: 답변 내 엔티티가 그래프에 존재하는지 자동 검증
- **Wiki 자동 생성**: 그래프 노드 기반 Wiki 페이지 자동 생성/갱신

## 성공 지표
| 지표 | 목표 |
|---|---|
| 챗봇 해결율 | 60%+ (상담원 연결 없이) |
| 상담원 Good 비율 | 80%+ |
| 할루시네이션율 | 5% 미만 |
| 재질문율 | 20% 미만 |
| 지식 커버리지 | 6개월 내 전체 SKU 80%+ |