# PSP Defect Recording Log

- Name: Graham Lee
- Date: 2026-03-18
- Program: AppScript (Issue appscript-ewo)
- Language: Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
|AppScript-ewo|2026-03-18 20:39|1|10|Test|Test|20 min| |Omitted integration test (StringEscapes.appscript + .expected) from initial Test phase|
|AppScript-ewo|2026-03-18 20:39|2|10|Test|Test|2 min| |Omitted README.md and ARCHITECTURE.md documentation updates from scope|
|AppScript-ewo|2026-03-18 21:00|3|7|Test|Test|5 min|1|Integration test crashed: no .expected file → URLForResource: returns nil → [ASNull as_stringContents] aborts. Created StringEscapes.expected to fix|
|AppScript-ewo|2026-03-18 21:00|4|10|Test|Test|8 min|1|Initial .expected file had wrong content (included \"  item that doesn't format as expected in NSArray description). Simplified test and fixed expected file|
