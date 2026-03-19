# PSP Defect Recording Log

- Name: Claude
- Date: 2026-03-19
- Program: appscript-isd — Add GNUmakefile harness app target
- Language: GNUmake

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| appscript-isd | 2026-03-19T16:36:10+00:00 | 1 | 80 | Code | Compile | 2 min | | RESOURCE_DIRS only creates empty dirs in bundle; must use RESOURCE_FILES to copy scripts |
| appscript-isd | 2026-03-19T16:44:10+00:00 | 2 | 80 | Code | Test | 5 min | | NSMainNibFile empty in Info.plist; xib not compiled/bundled so UI never appears. Fixed by adding MAIN_MODEL_FILE and after-all ibtool step |
| appscript-isd | 2026-03-19T16:49:40+00:00 | 3 | 80 | Code | Test | 5 min | | AppScript.framework has relative install name; dyld can't find it when app launched via open. Fix: embed framework in app bundle and rewrite link reference |
| appscript-isd | 2026-03-19T16:54:00+00:00 | 4 | 80 | Code | Test | 3 min | | libgnustep-baseadd.1.31.dylib bare name unresolvable from launched app; no headerpad room to change. Fix: add -Wl,-headerpad_max_install_names and relink |
| appscript-isd | 2026-03-19T16:57:00+00:00 | 5 | 80 | Code | Test | 3 min | | codesign --preserve-metadata=entitlements fails on unsigned binary after clean. Fix: remove --preserve-metadata=entitlements flag |
| appscript-isd | 2026-03-19T17:05:00+00:00 | 6 | 80 | Code | Test | 6 min | | Scripts placed in Resources/Scripts/ subdirectory; URLsForResourcesWithExtension:subdirectory:nil only searches Resources/ top level so classes not loaded. Fix: use RESOURCE_FILES_DIR + wildcard to copy files directly to Resources/ |
