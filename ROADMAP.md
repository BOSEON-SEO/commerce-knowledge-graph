## Phase 1: Foundation
**목표**: 그래프 DB + 벡터 DB 기반 인프라 구축 및 초기 데이터 seed

### 주요 산출물
- [x] Docker Compose: Neo4j + PostgreSQL(pgvector) + Redis 컨테이너 구성
- [x] Neo4j 초기 스키마 정의 (노드 라벨 10종 + 엣지 타입 9종)
- [x] PostgreSQL(pgvector) 스키마 정의 (manuals + vector_chunks 테이블, IVFFlat 인덱스, 유사도 검색 함수)
- [x] 스택 초기화 스크립트 (`init-stack.sh`) + 검증 스크립트 (`validate-stack.sh`)
- [ ] 맥락별 엣지 화이트리스트 설정 파일
- [ ] 제품 카탈로그 → Neo4j ETL 스크립트 (Kafka+Debezium 또는 직접 import)
- [ ] A/S 매뉴얼 20개 seed: 청킹 → pgvector 적재
- [ ] FastAPI 기본 뼈대 (health check + Auth + Role Middleware)

### DoD
- [x] `docker-compose up` 한 번에 전체 스택 기동
- [ ] Neo4j Browser에서 샘플 Product-Part-Symptom 그래프 시각화 확인
- [ ] pgvector에 매뉴얼 20개 chunk 적재 및 유사도 쿼리 응답 확인
- [ ] API Gateway가 맥락별 엣지 화이트리스트를 자동 적용함을 단위 테스트로 검증

---

## Phase 2: LLM + 인터랙티브 학습소 MVP
**목표**: LLM 기반 Query Planner + Answer Synthesizer 구축, 인터랙티브 학습소 내부 MVP 완성

### 주요 산출물
- Ollama 로컬 LLM 연동 (단순 FAQ → Redis 캐시, 중간 → 로컬 LLM, 복잡 → 외부 API 라우팅)
- Query Planner: 자연어 → Cypher + vector query 변환
- Context Merger: 그래프 결과 + 벡터 결과 통합 정렬
- Answer Synthesizer: 출처 명시 + streaming 응답
- **인터랙티브 학습소 MVP**: PDF/Excel/JSON/텍스트 드래그앤드롭 → LLM 분석 → 구조화 프리뷰 → 품질 리포트 → 컨펌 시 백엔드 저장
- Good/Bad 피드백 시스템: Bad → LLM 교정안 → 담당자 컨펌 → 그래프 업데이트

### DoD
- [ ] "세탁기 드럼 소리나요" 질문에 올바른 그래프 traversal + 매뉴얼 chunk 참조 답변 생성
- [ ] 학습소에 PDF 업로드 시 품질 리포트 + 구조화 프리뷰 표시
- [ ] Bad 피드백 → 교정안 생성 → 컨펌 → Neo4j 즉시 반영 E2E 확인
- [ ] 캐시 히트 응답 < 0.1초, 일반 응답 streaming 시작 < 0.5초

---

## Phase 3: Wiki UI + CS 상담원 파일럿
**목표**: Wiki UI 공개, CS 상담원 내부 파일럿 운영, 권한별 접근 제어 완성

### 주요 산출물
- Next.js Wiki UI (Wikipedia 형식, 고객 읽기전용 / 내부 편집가능)
- CS 상담원용 챗봇 UI (고객 이력 포함 전체 엣지 접근)
- Wiki Writer Agent: 그래프 노드 기반 Wiki 페이지 자동 생성/갱신
- 고객용 챗봇 + 위키 공개 (PDP 화이트리스트 적용)
- 인터랙티브 학습소 UI 개선 (비개발 직원 사용 가능 수준)
- 할루시네이션 자동 탐지 (답변 내 엔티티 그래프 존재 여부 검증)

### DoD
- [ ] CS 상담원이 고객 이력 포함 전체 그래프 접근, 고객 챗봇은 PDP 범위만 접근 확인
- [ ] Wiki 페이지 그래프 업데이트 시 5분 내 자동 갱신
- [ ] 할루시네이션율 5% 미만 내부 측정
- [ ] 내부 파일럿 Good 비율 60%+ 달성

---

## Phase 4: Optimization + 자동화
**목표**: Lint 자동화, 비용 모니터링, 성과 보고 체계 구축

### 주요 산출물
- Lint Agent: 주기적 고아 페이지, 링크 누락, 모순 자동 탐지
- 비용 모니터링 대시보드 (LLM 호출 비용, 캐시 히트율)
- 도메인 특화 임베딩 모델 fine-tuning (제품명/증상)
- before/after 성과 보고서 자동 생성
- 재질문율 자동 측정 (같은 세션 같은 주제 재질문 탐지)

### DoD
- [ ] Lint Agent가 매일 자동 실행 + 교정 필요 항목 슬랙/이메일 알림
- [ ] 챗봇 해결율 60%+, 상담원 Good 비율 80%+, 재질문율 20% 미만 달성
- [ ] 지식 커버리지 전체 SKU 50%+ (6개월 목표 80%+ 트래킹 시작)
- [ ] 비용 모니터링 대시보드에서 월간 LLM 비용 추이 확인 가능