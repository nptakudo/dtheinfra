# Lessons Learned

## Session: 2026-02-06 - Iceberg + DataHub Integration

### Lesson 1: Always Follow CLAUDE.md Workflow
**What happened:** Jumped straight into implementation without creating `tasks/todo.md` and tracking progress according to CLAUDE.md guidelines.

**Why it matters:** The workflow exists for good reasons:
- `tasks/todo.md` provides checkable progress tracking
- Forces upfront planning and reduces scope creep
- Creates documentation trail for teammates
- Review section captures what worked/didn't work
- Lessons.md captures patterns for future sessions

**Rule for next time:**
- After exiting plan mode, FIRST action is to create `tasks/todo.md` with checkable items from the plan
- Use TaskCreate/TaskUpdate for in-memory tracking during session
- Write review section to `tasks/todo.md` when marking tasks complete
- Update `tasks/lessons.md` immediately after any correction from user

### Lesson 2: Component Pattern is Key for Monorepo Infra
**What worked well:** Establishing the independent component pattern with:
- Separate docker-compose stacks per component
- Shared `dtheinfra-network` for cross-component communication
- Standardized lifecycle scripts (start/stop)
- `.env.example` for configuration templates

**Why it matters:** Enables parallel development by teammates without merge conflicts or dependencies.

**Pattern to replicate:**
```
infra/<component>/
  ├── README.md
  └── dev/
      ├── docker-compose.yml  (declares external dtheinfra-network)
      ├── .env.example
      ├── start-<component>.sh
      └── stop-<component>.sh
```

### Lesson 3: Document Multiple Levels
**What worked:** Created documentation at three levels:
1. **Quickstart** (`QUICKSTART.md`) - Step-by-step for getting started
2. **Component** (`README.md` per component) - Component-specific usage
3. **Pattern** (`COMPONENT_PATTERN.md`) - Reusable architecture patterns

**Why it matters:** Different audiences need different levels of detail:
- New users want step-by-step
- Component maintainers need component details
- Infrastructure architects need patterns

**Rule:** For any non-trivial infrastructure work, create all three levels.

### Lesson 4: Real vs Emulated Infrastructure
**Decision:** Use real GCS instead of emulating with MinIO/Fake GCS.

**Trade-offs:**
- **Pro:** Production-like from day one, avoids emulator quirks
- **Pro:** Tests real authentication, permissions, network paths
- **Con:** Requires GCP credentials, can't fully automate POC
- **Con:** Costs (though minimal for POC scale)

**Rule:** For storage/cloud services, prefer real over emulated when:
- Authentication/permissions are part of the integration
- Emulator has known compatibility issues
- Cost is acceptable for dev/POC scale

Use emulators when:
- Fully offline development is required
- Cost would be prohibitive
- Emulator is mature and widely used (e.g., LocalStack for AWS)

### Lesson 5: Verification Scripts Save Time
**What worked:** Created `verify-integration.sh` that checks:
- Network exists
- Services are healthy
- Cross-component connectivity works
- Provides actionable next steps

**Why it matters:** Reduces "is it working?" questions, faster debugging.

**Pattern to replicate:** For any multi-component integration, create a verification script that:
- Checks prerequisites (networks, credentials)
- Tests each component independently
- Tests integration (cross-component connectivity)
- Provides clear pass/fail with next steps

### Lesson 6: Catalog Choice is Orthogonal to Integration
**Key insight:** DataHub's `iceberg` source works with ANY catalog exposing the Iceberg REST API (Lakekeeper, Nessie, Polaris, etc.).

**Why it matters:** Can choose catalog based on operational requirements (versioning, RBAC, resource footprint) without affecting the DataHub side.

**Rule:** When integrating with standards-based systems (REST APIs, protocols), validate the integration works with the reference implementation first, then swap components as needed.

### Lesson 7: GCS-Native Requires the Right Catalog
**What almost went wrong:** Original plan mentioned `tabulario/iceberg-rest` which doesn't ship with GCS jars by default.

**Resolution:** Chose Lakekeeper which has native GCS support built-in (Rust-based).

**Rule:** When using non-S3 storage (GCS, Azure Blob), verify the catalog/engine has native support, not just "it can be configured". Native support = ships with the right JARs/libraries by default.

## Patterns to Remember

### Docker Network Convention
```yaml
networks:
  default:
    name: <component>_internal_network
  dtheinfra:
    external: true
    name: dtheinfra-network

services:
  internal-svc:
    networks: [default]

  exposed-svc:
    networks: [default, dtheinfra]
```

### Lifecycle Script Pattern
```bash
#!/bin/bash
set -euo pipefail

# 1. Check Docker running
# 2. Ensure shared network exists
# 3. Load .env if present
# 4. Start services
# 5. Wait for health
# 6. Print status + next steps
```

### PyIceberg Catalog Loading
```python
from pyiceberg.catalog import load_catalog

catalog = load_catalog(
    "catalog_name",
    **{
        "type": "rest",
        "uri": "http://localhost:8181",
        "warehouse": "gs://bucket/path/",
    }
)
```

## Action Items for Next Session
- [ ] Follow CLAUDE.md workflow from the start
- [ ] Create `tasks/todo.md` immediately after planning
- [ ] Add more schema evolution examples to docs
- [ ] Consider Makefile targets for common operations
- [ ] Test with real GCS bucket to validate full E2E
