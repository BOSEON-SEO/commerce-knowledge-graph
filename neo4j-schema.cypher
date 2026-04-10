// ============================================================
// Commerce Knowledge Graph – Neo4j Schema
// 노드 라벨 10종 + 엣지 타입 9종
// ============================================================

// ────────────────────────────────────────────────
// 1. 제약 조건 (Uniqueness Constraints)
// ────────────────────────────────────────────────
CREATE CONSTRAINT product_id_unique   IF NOT EXISTS FOR (n:Product)        REQUIRE n.productId IS UNIQUE;
CREATE CONSTRAINT part_id_unique      IF NOT EXISTS FOR (n:Part)           REQUIRE n.partId IS UNIQUE;
CREATE CONSTRAINT symptom_id_unique   IF NOT EXISTS FOR (n:Symptom)        REQUIRE n.symptomId IS UNIQUE;
CREATE CONSTRAINT cause_id_unique     IF NOT EXISTS FOR (n:Cause)          REQUIRE n.causeId IS UNIQUE;
CREATE CONSTRAINT solution_id_unique  IF NOT EXISTS FOR (n:Solution)       REQUIRE n.solutionId IS UNIQUE;
CREATE CONSTRAINT manual_id_unique    IF NOT EXISTS FOR (n:Manual)         REQUIRE n.manualId IS UNIQUE;
CREATE CONSTRAINT diagnostic_id_unique IF NOT EXISTS FOR (n:Diagnostic)    REQUIRE n.diagnosticId IS UNIQUE;
CREATE CONSTRAINT doctype_name_unique IF NOT EXISTS FOR (n:DocumentType)   REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT category_name_unique IF NOT EXISTS FOR (n:Category)      REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT status_name_unique  IF NOT EXISTS FOR (n:Status)         REQUIRE n.name IS UNIQUE;

// ────────────────────────────────────────────────
// 2. 인덱스 (Indexes)
// ────────────────────────────────────────────────
CREATE INDEX product_name_idx        IF NOT EXISTS FOR (n:Product)      ON (n.name);
CREATE INDEX product_model_idx       IF NOT EXISTS FOR (n:Product)      ON (n.modelNumber);
CREATE INDEX part_name_idx           IF NOT EXISTS FOR (n:Part)         ON (n.name);
CREATE INDEX symptom_keyword_idx     IF NOT EXISTS FOR (n:Symptom)      ON (n.keyword);
CREATE INDEX cause_keyword_idx       IF NOT EXISTS FOR (n:Cause)        ON (n.keyword);
CREATE INDEX solution_title_idx      IF NOT EXISTS FOR (n:Solution)     ON (n.title);
CREATE INDEX manual_title_idx        IF NOT EXISTS FOR (n:Manual)       ON (n.title);
CREATE INDEX diagnostic_code_idx     IF NOT EXISTS FOR (n:Diagnostic)   ON (n.code);
CREATE INDEX category_name_idx       IF NOT EXISTS FOR (n:Category)     ON (n.name);

// ────────────────────────────────────────────────
// 3. 노드 라벨별 속성 정의 (주석)
// ────────────────────────────────────────────────

// (:Product)
//   productId    : STRING   – 고유 식별자
//   name         : STRING   – 제품명
//   modelNumber  : STRING   – 모델 번호
//   brand        : STRING   – 브랜드
//   description  : STRING   – 설명
//   createdAt    : DATETIME – 등록일시
//   updatedAt    : DATETIME – 수정일시

// (:Part)
//   partId       : STRING   – 고유 식별자
//   name         : STRING   – 부품명
//   partNumber   : STRING   – 부품 번호
//   description  : STRING   – 설명
//   price        : FLOAT    – 가격
//   availability : BOOLEAN  – 재고 여부

// (:Symptom)
//   symptomId    : STRING   – 고유 식별자
//   keyword      : STRING   – 증상 키워드
//   description  : STRING   – 상세 설명
//   severity     : STRING   – 심각도 (low/medium/high/critical)

// (:Cause)
//   causeId      : STRING   – 고유 식별자
//   keyword      : STRING   – 원인 키워드
//   description  : STRING   – 상세 설명
//   frequency    : STRING   – 빈도 (rare/occasional/frequent)

// (:Solution)
//   solutionId   : STRING   – 고유 식별자
//   title        : STRING   – 솔루션 제목
//   steps        : LIST<STRING> – 해결 단계
//   difficulty   : STRING   – 난이도 (easy/medium/hard)
//   estimatedTime: STRING   – 예상 소요 시간

// (:Manual)
//   manualId     : STRING   – 고유 식별자
//   title        : STRING   – 매뉴얼 제목
//   version      : STRING   – 버전
//   fileUrl      : STRING   – 파일 경로/URL
//   language     : STRING   – 언어
//   publishedAt  : DATETIME – 발행일

// (:Diagnostic)
//   diagnosticId : STRING   – 고유 식별자
//   code         : STRING   – 진단 코드
//   description  : STRING   – 설명
//   procedure    : STRING   – 진단 절차

// (:DocumentType)
//   name         : STRING   – 문서 유형명 (e.g. 사용자매뉴얼, 수리가이드, FAQ)
//   description  : STRING   – 설명

// (:Category)
//   name         : STRING   – 카테고리명
//   description  : STRING   – 설명
//   parentName   : STRING   – 상위 카테고리 (nullable)

// (:Status)
//   name         : STRING   – 상태명 (e.g. active, deprecated, draft)
//   description  : STRING   – 설명

// ────────────────────────────────────────────────
// 4. 엣지 타입별 속성 정의 (주석)
// ────────────────────────────────────────────────

// [:HAS_PART]       (Product)-[:HAS_PART]->(Part)
//   quantity   : INTEGER – 수량
//   required   : BOOLEAN – 필수 여부

// [:HAS_SYMPTOM]    (Product)-[:HAS_SYMPTOM]->(Symptom)
//   reportedCount : INTEGER – 리포트 횟수
//   firstReported : DATETIME

// [:HAS_CAUSE]      (Symptom)-[:HAS_CAUSE]->(Cause)
//   probability : FLOAT – 원인 확률 (0.0~1.0)

// [:HAS_SOLUTION]   (Cause)-[:HAS_SOLUTION]->(Solution)
//   effectiveness : FLOAT – 효과 (0.0~1.0)
//   verifiedAt    : DATETIME

// [:DOCUMENTED_IN]  (Product|Solution)-[:DOCUMENTED_IN]->(Manual)
//   section : STRING – 관련 섹션
//   page    : INTEGER

// [:BELONGS_TO]     (Product|Manual)-[:BELONGS_TO]->(Category)
//   since : DATETIME

// [:RELATES_TO]     (Product)-[:RELATES_TO]->(Product)
//   relationType : STRING – (accessory, replacement, upgrade)

// [:CAUSED_BY]      (Symptom)-[:CAUSED_BY]->(Part)
//   confidence : FLOAT – 확신도

// [:REQUIRES]       (Solution)-[:REQUIRES]->(Part)
//   quantity : INTEGER
//   optional : BOOLEAN

// ────────────────────────────────────────────────
// 5. 샘플 Status / DocumentType / Category 초기 데이터
// ────────────────────────────────────────────────
MERGE (s1:Status {name: 'active'})      SET s1.description = '현재 사용 중';
MERGE (s2:Status {name: 'deprecated'})  SET s2.description = '더 이상 사용하지 않음';
MERGE (s3:Status {name: 'draft'})       SET s3.description = '작성 중';

MERGE (dt1:DocumentType {name: '사용자매뉴얼'})  SET dt1.description = '최종 사용자용 매뉴얼';
MERGE (dt2:DocumentType {name: '수리가이드'})    SET dt2.description = '수리 기술자용 가이드';
MERGE (dt3:DocumentType {name: 'FAQ'})           SET dt3.description = '자주 묻는 질문';

MERGE (c1:Category {name: '가전'})        SET c1.description = '가전제품', c1.parentName = null;
MERGE (c2:Category {name: '세탁기'})      SET c2.description = '세탁기 카테고리', c2.parentName = '가전';
MERGE (c3:Category {name: '냉장고'})      SET c3.description = '냉장고 카테고리', c3.parentName = '가전';
MERGE (c4:Category {name: 'TV'})          SET c4.description = 'TV 카테고리',    c4.parentName = '가전';
MERGE (c5:Category {name: '에어컨'})      SET c5.description = '에어컨 카테고리', c5.parentName = '가전';
