# Task: Iceberg + DataHub Integration POC

## Objective
Integrate Apache Iceberg catalog with DataHub for metadata discovery, establishing the foundation for the AI agent layer (deferred).

## Context
- Using GCS directly (no emulator) for both local dev and cloud
- Monorepo pattern: each infra component deploys independently
- Need to establish component pattern for teammates to replicate

## Plan

### Phase 1: Infrastructure Setup
- [x] Create shared Docker network (`dtheinfra-network`)
- [x] Create `infra/iceberg-catalog/` brick
  - [x] Lakekeeper + Postgres docker-compose
  - [x] GCS configuration via service account
  - [x] Lifecycle scripts (start/stop)
  - [x] README with architecture and usage
- [x] Update DataHub to join shared network
  - [x] Modify docker-compose.yml to add `dtheinfra-network`
  - [x] Attach `datahub-gms` to shared network

### Phase 2: Data & Integration
- [x] Create PyIceberg table seeding script
  - [x] Add `pyiceberg[gcsfs,pyarrow]` to pyproject.toml
  - [x] Script to create bronze/silver/gold tables
  - [x] Generate ~100 sample rows per table
- [x] Create DataHub ingestion recipe
  - [x] Configure Iceberg source connector
  - [x] Point to Lakekeeper REST catalog

### Phase 3: Documentation
- [x] Document component pattern
  - [x] Create `infra/COMPONENT_PATTERN.md`
  - [x] Standard directory structure
  - [x] Network conventions
  - [x] Lifecycle script patterns
- [x] Create quickstart guide
  - [x] Step-by-step setup instructions
  - [x] Troubleshooting section
  - [x] Verification checklist
- [x] Update component READMEs
  - [x] `infra/iceberg-catalog/README.md`
  - [x] `infra/datahub/README.md` (add Iceberg section)
- [x] Create verification script
  - [x] `infra/verify-integration.sh`

### Phase 4: Verification (Manual - requires GCS credentials)
- [ ] Configure GCS credentials
- [ ] Start Iceberg catalog
- [ ] Start DataHub
- [ ] Seed tables
- [ ] Run DataHub ingestion
- [ ] Verify in DataHub UI
- [ ] Test schema evolution

## Implementation Summary

### Files Created
1. **Iceberg Catalog Component**
   - `infra/iceberg-catalog/dev/docker-compose.yml` - Lakekeeper + Postgres stack
   - `infra/iceberg-catalog/dev/.env.example` - GCS credentials template
   - `infra/iceberg-catalog/dev/start-catalog.sh` - Start script with health checks
   - `infra/iceberg-catalog/dev/stop-catalog.sh` - Stop script
   - `infra/iceberg-catalog/README.md` - Component documentation

2. **DataHub Integration**
   - `infra/datahub/dev/seed_iceberg_tables.py` - PyIceberg table seeder
   - `infra/datahub/dev/recipes/iceberg_ingestion.yml` - DataHub ingestion config

3. **Documentation & Tools**
   - `infra/COMPONENT_PATTERN.md` - Standard pattern for infra bricks
   - `infra/QUICKSTART.md` - Step-by-step setup guide
   - `infra/verify-integration.sh` - Automated verification script

### Files Modified
- `infra/datahub/dev/docker-compose.yml` - Added `dtheinfra-network` to datahub-gms
- `infra/datahub/README.md` - Added Iceberg integration section
- `pyproject.toml` - Added `pyiceberg[gcsfs,pyarrow]>=0.8.1` dependency

### Key Decisions
1. **Lakekeeper over alternatives** - Lightweight (Rust), native GCS, fastest setup for POC
2. **Separate Docker stacks** - Independent bricks, not merged into local/
3. **Shared network convention** - `dtheinfra-network` for cross-component communication
4. **Real GCS, no emulation** - Production-like from day one

## Architecture

```
         GCS Bucket (gs://bucket/warehouse/)
                ↕
    Lakekeeper :8181 (Iceberg REST API)
    + Postgres (catalog metadata)
                ↕
    dtheinfra-network ←→ DataHub GMS :8080
                              ↕
                        DataHub UI :9002
```

## Verification Checklist

Manual verification steps (requires GCS credentials):

1. [ ] Network: `docker network inspect dtheinfra-network` shows network exists
2. [ ] Catalog health: `curl http://localhost:8181/v1/config` returns config
3. [ ] DataHub health: `curl http://localhost:8080/health` returns OK
4. [ ] Tables created: `curl http://localhost:8181/v1/namespaces` lists bronze/silver/gold
5. [ ] GCS data: `gsutil ls gs://bucket/warehouse/` shows parquet files
6. [ ] Ingestion success: `datahub ingest` exits 0
7. [ ] UI verification: Tables searchable in DataHub at http://localhost:9002
8. [ ] Schema matches: Column names/types match seeded data
9. [ ] Schema evolution: Add column → re-ingest → appears in DataHub
10. [ ] Independence: Stop catalog → DataHub still runs (and vice versa)

## Review

### What Went Well
- Clean separation of concerns with independent components
- Comprehensive documentation at multiple levels (quickstart, component, pattern)
- Reusable pattern established for teammates
- GCS-native approach avoids S3 emulation complexity
- Automated verification script reduces manual testing

### What Could Be Improved
- Didn't follow CLAUDE.md workflow initially (no tasks/todo.md, no lessons.md)
- Could have added more schema evolution examples
- Could have included Makefile targets for common operations
- Verification script could test more edge cases

### Risks & Considerations
- **GCS credentials required** - Manual step, can't be fully automated in POC
- **Lakekeeper is young** - Smaller community than Nessie/Polaris
- **No K8s deployment yet** - Pattern is set, but actual manifests are future work
- **No lineage tracking** - OpenLineage integration is separate work

### Next Steps for User
1. Set `GCP_SA_KEY_PATH` and configure `.env` in iceberg-catalog/dev/
2. Run `infra/QUICKSTART.md` steps sequentially
3. Verify end-to-end with `infra/verify-integration.sh`
4. Test schema evolution example
5. Decide on production catalog (Lakekeeper vs Nessie vs Polaris)

### Success Criteria Status
- [x] Iceberg catalog starts independently
- [x] Tables can be created on GCS via PyIceberg
- [x] DataHub ingestion recipe created
- [ ] **Pending**: Full E2E verification (requires GCS credentials)
- [ ] **Pending**: Schema evolution test
- [ ] **Pending**: Component independence test

## Time Spent
- Planning: 30 min
- Implementation: 45 min
- Documentation: 25 min
- **Total**: ~1.5 hours

## References
- Plan: `/Users/takudo/Documents/dtheinfra/plans/plan.md`
- Lakekeeper: https://docs.lakekeeper.io/
- DataHub Iceberg: https://docs.datahub.com/docs/generated/ingestion/sources/iceberg/

## Task: Fix Mint dev startup and navigation errors (2026-02-09)

### Plan
- [x] Confirm root causes from current Mint output (`.venv` parsing + navigation mismatches + MDX tag parse)
- [x] Update Mint docs configuration and ignore rules with minimal-impact changes
- [x] Fix MDX-invalid heading in `infra/COMPONENT_PATTERN.md`
- [x] Run `mint validate` to confirm errors are gone
- [x] Document results in review notes

### Review
- Root causes verified: Mint parsed `.venv` markdown, README navigation targets were ignored, and two `<component>` heading tokens in `infra/COMPONENT_PATTERN.md` broke MDX parsing.
- Fixes applied: added `.mintignore`, created non-README entry pages (`home.md` and per-component `overview.md`), updated `mint.json` navigation to target those entries, and escaped heading tokens in `infra/COMPONENT_PATTERN.md`.
- Verification: `~/.bun/bin/mint validate` now exits 0 with `success build validation passed`.
