-- ============================================================
-- Commerce Knowledge Graph – PostgreSQL Schema
-- pgvector 확장 + 벡터 검색 테이블
-- ============================================================

-- 1. pgvector 확장 활성화
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. manuals 메타데이터 테이블
CREATE TABLE IF NOT EXISTS manuals (
    id              SERIAL PRIMARY KEY,
    manual_id       VARCHAR(64)  NOT NULL UNIQUE,   -- Neo4j Manual.manualId 와 매핑
    title           VARCHAR(512) NOT NULL,
    version         VARCHAR(32),
    language        VARCHAR(16)  DEFAULT 'ko',
    file_url        TEXT,
    document_type   VARCHAR(64),                     -- 사용자매뉴얼, 수리가이드, FAQ 등
    product_id      VARCHAR(64),                     -- Neo4j Product.productId 참조
    page_count      INTEGER,
    published_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  DEFAULT NOW()
);

-- manuals 보조 인덱스
CREATE INDEX IF NOT EXISTS idx_manuals_product_id   ON manuals (product_id);
CREATE INDEX IF NOT EXISTS idx_manuals_doc_type     ON manuals (document_type);
CREATE INDEX IF NOT EXISTS idx_manuals_title        ON manuals USING GIN (to_tsvector('simple', title));

-- 3. vector_chunks 테이블
CREATE TABLE IF NOT EXISTS vector_chunks (
    id              SERIAL PRIMARY KEY,
    manual_id       VARCHAR(64)  NOT NULL REFERENCES manuals(manual_id) ON DELETE CASCADE,
    chunk_index     INTEGER      NOT NULL,           -- 매뉴얼 내 청크 순서
    chunk_text      TEXT         NOT NULL,            -- 원본 텍스트
    embedding       vector(1536) NOT NULL,            -- OpenAI text-embedding-ada-002 기준 1536차원
    token_count     INTEGER,
    page_number     INTEGER,                          -- 원본 페이지 번호
    metadata        JSONB        DEFAULT '{}',        -- 추가 메타데이터
    created_at      TIMESTAMPTZ  DEFAULT NOW()
);

-- vector_chunks 보조 인덱스
CREATE INDEX IF NOT EXISTS idx_chunks_manual_id  ON vector_chunks (manual_id);
CREATE INDEX IF NOT EXISTS idx_chunks_page       ON vector_chunks (page_number);
CREATE INDEX IF NOT EXISTS idx_chunks_metadata   ON vector_chunks USING GIN (metadata);

-- 4. 벡터 유사도 검색 인덱스 (IVFFlat – 코사인 거리)
--    lists 값은 데이터 양에 따라 조정 (sqrt(총 행 수) 권장)
CREATE INDEX IF NOT EXISTS idx_chunks_embedding_ivfflat
    ON vector_chunks
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- 5. 유사도 검색 함수
CREATE OR REPLACE FUNCTION search_similar_chunks(
    query_embedding vector(1536),
    match_count     INTEGER DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.7
)
RETURNS TABLE (
    id          INTEGER,
    manual_id   VARCHAR(64),
    chunk_text  TEXT,
    page_number INTEGER,
    similarity  FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        vc.id,
        vc.manual_id,
        vc.chunk_text,
        vc.page_number,
        1 - (vc.embedding <=> query_embedding)::FLOAT AS similarity
    FROM vector_chunks vc
    WHERE 1 - (vc.embedding <=> query_embedding)::FLOAT >= similarity_threshold
    ORDER BY vc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 6. updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_manuals_updated_at
    BEFORE UPDATE ON manuals
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();
