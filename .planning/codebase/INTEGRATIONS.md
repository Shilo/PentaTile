# External Integrations

**Analysis Date:** 2026-04-26

## APIs & External Services

**None currently implemented.**

The PentaTile addon is a self-contained tilemap layer that does not integrate with external APIs, cloud services, or third-party SDKs.

## Data Storage

**Databases:**
- None (not applicable to addon/game context)

**File Storage:**
- Local filesystem only
- Textures embedded in project: `addons/penta_tile/demo/penta_tile_ground.png`, `addons/penta_tile/penta_tile_template.png`
- Scene files stored as `.tscn` (text-based Godot scenes)
- TileSet definitions stored as `.tres` resource files

**Caching:**
- None (Godot's internal editor caching only, no external caching layer)

## Authentication & Identity

**Auth Provider:**
- None (not applicable)

**Implementation:**
- No user authentication required
- Single-user game dev context

## Monitoring & Observability

**Error Tracking:**
- None (standard Godot console output for errors/warnings)

**Logs:**
- Standard Godot console output (visible in editor and game terminal)
- No structured logging framework

## CI/CD & Deployment

**Hosting:**
- Godot games export to native executables or web (WASM)
- No deployment platform configured
- MCP Server for Godot integration: `@coding-solo/godot-mcp` (dev tooling)

**CI Pipeline:**
- None detected

## Environment Configuration

**Required env vars:**
- `GODOT_PATH` - Configured in `.mcp.json` for Godot MCP server: `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe`

**Secrets location:**
- No secrets required (not applicable to addon)

## MCP Server Integration

**Godot MCP Server:**
- Type: stdio
- Command: `npx @coding-solo/godot-mcp`
- Configuration file: `.mcp.json`
- Purpose: IDE/editor integration support for Godot development
- Env var: `GODOT_PATH` points to Godot 4.6.2 executable

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Input/Output Handling

**Runtime Input:**
- Mouse input captured via Godot's `InputEvent` system
- `demo_runtime_painter.gd` handles:
  - Left-click to place tiles (calls `set_cell()`)
  - Right-click to erase tiles (calls `erase_cell()`)
  - Mouse motion tracking for continuous painting

**Editor Integration:**
- Native Godot TileMap painting tools
- Inspector properties for property tweaking
- Scene tree node hierarchy

---

*Integration audit: 2026-04-26*
