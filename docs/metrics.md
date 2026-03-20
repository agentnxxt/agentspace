# Metrics

Prometheus-compatible metrics endpoint. Opt-in via the `metrics` cargo feature flag.

## Building with Metrics

```bash
cargo build --release --features metrics
```

Without the feature flag, all telemetry code is compiled out. The `[metrics]` config block is parsed regardless but has no effect.

### Docker

The Docker image always includes metrics — `--features metrics` is hardcoded in the Dockerfile.

## Configuration

```toml
[metrics]
enabled = true
port = 9090
bind = "0.0.0.0"
```

| Key       | Default     | Description                          |
| --------- | ----------- | ------------------------------------ |
| `enabled` | `false`     | Enable the /metrics HTTP endpoint    |
| `port`    | `9090`      | Port for the metrics server          |
| `bind`    | `"0.0.0.0"` | Address to bind the metrics server  |

The metrics server runs as a separate tokio task alongside the main API server. It shuts down gracefully with the rest of the process.

## Endpoints

| Path       | Description                              |
| ---------- | ---------------------------------------- |
| `/metrics` | Prometheus text exposition format (0.0.4)|
| `/health`  | Returns 200 OK (for liveness probes)     |

## Exposed Metrics

All metrics are prefixed with `agentspace_`. For detailed per-metric documentation, see `METRICS.md`.

### LLM Metrics

| Metric                                  | Type      | Labels                                     | Description                        |
| --------------------------------------- | --------- | ------------------------------------------ | ---------------------------------- |
| `agentspace_llm_requests_total`           | Counter   | agent_id, model, tier, worker_type         | Total LLM completion requests      |
| `agentspace_llm_request_duration_seconds` | Histogram | agent_id, model, tier, worker_type         | LLM request duration               |
| `agentspace_llm_tokens_total`             | Counter   | agent_id, model, tier, direction, worker_type | Token counts (input/output/cached) |
| `agentspace_llm_estimated_cost_dollars`   | Counter   | agent_id, model, tier, worker_type         | Estimated cost in USD              |

The `tier` label corresponds to the process type making the request: `channel`, `branch`, `worker`, `compactor`, or `cortex`. The `worker_type` label identifies the worker variant: `builtin`, `opencode`, or `ingestion`; non-worker tiers emit an empty string.

### Tool Metrics

| Metric                                    | Type      | Labels                              | Description                         |
| ----------------------------------------- | --------- | ----------------------------------- | ----------------------------------- |
| `agentspace_tool_calls_total`               | Counter   | agent_id, tool_name, process_type   | Total tool calls executed           |
| `agentspace_tool_call_duration_seconds`     | Histogram | agent_id, tool_name, process_type   | Tool call execution duration        |

### MCP Metrics

| Metric                                            | Type      | Labels                 | Description                         |
| ------------------------------------------------- | --------- | ---------------------- | ----------------------------------- |
| `agentspace_mcp_connections`                        | Gauge     | server_name, state     | Active MCP connections by state     |
| `agentspace_mcp_tools_registered`                   | Gauge     | server_name            | Tools registered per MCP server     |
| `agentspace_mcp_connection_attempts_total`          | Counter   | server_name, result    | MCP connection attempts             |
| `agentspace_mcp_tool_calls_total`                   | Counter   | server_name, tool_name | MCP tool calls                      |
| `agentspace_mcp_reconnects_total`                   | Counter   | server_name            | Successful MCP reconnections        |
| `agentspace_mcp_connection_duration_seconds`        | Histogram | server_name            | MCP connection establishment time   |
| `agentspace_mcp_tool_call_duration_seconds`         | Histogram | server_name, tool_name | MCP tool call duration              |

### Channel / Messaging Metrics

| Metric                                            | Type      | Labels                              | Description                         |
| ------------------------------------------------- | --------- | ----------------------------------- | ----------------------------------- |
| `agentspace_messages_received_total`                | Counter   | agent_id, channel_type              | Total messages received             |
| `agentspace_messages_sent_total`                    | Counter   | agent_id, channel_type              | Total messages sent (replies)       |
| `agentspace_message_handling_duration_seconds`      | Histogram | agent_id, channel_type              | Message handling duration           |
| `agentspace_channel_errors_total`                   | Counter   | agent_id, channel_type, error_type  | Channel-level errors                |

### Agent & Worker Metrics

| Metric                                  | Type      | Labels                                          | Description                        |
| --------------------------------------- | --------- | ----------------------------------------------- | ---------------------------------- |
| `agentspace_active_workers`               | Gauge     | agent_id                                        | Currently active workers           |
| `agentspace_active_branches`              | Gauge     | agent_id                                        | Currently active branches          |
| `agentspace_branches_spawned_total`       | Counter   | agent_id                                        | Total branches spawned             |
| `agentspace_worker_duration_seconds`      | Histogram | agent_id, worker_type                           | Worker lifetime duration           |
| `agentspace_context_overflow_total`       | Counter   | agent_id, process_type                          | Context overflow events            |
| `agentspace_process_errors_total`         | Counter   | agent_id, process_type, error_type, worker_type | Process errors by type             |

### Memory Metrics

| Metric                                          | Type      | Labels                | Description                         |
| ----------------------------------------------- | --------- | --------------------- | ----------------------------------- |
| `agentspace_memory_reads_total`                   | Counter   | agent_id              | Total memory recall operations      |
| `agentspace_memory_writes_total`                  | Counter   | agent_id              | Total memory save operations        |
| `agentspace_memory_entry_count`                   | Gauge     | agent_id              | Memory entries per agent            |
| `agentspace_memory_updates_total`                 | Counter   | agent_id, operation   | Memory mutations (save/delete/forget) |
| `agentspace_memory_operation_duration_seconds`    | Histogram | agent_id, operation   | Memory operation duration           |
| `agentspace_memory_search_results`                | Histogram | agent_id              | Search results per recall query     |
| `agentspace_memory_embedding_duration_seconds`    | Histogram |                       | Embedding generation duration       |

### Cost Metrics

| Metric                                  | Type      | Labels                 | Description                        |
| --------------------------------------- | --------- | ---------------------- | ---------------------------------- |
| `agentspace_worker_cost_dollars`          | Counter   | agent_id, worker_type  | Worker-specific cost in USD        |

### API Metrics

| Metric                                          | Type      | Labels                   | Description                         |
| ----------------------------------------------- | --------- | ------------------------ | ----------------------------------- |
| `agentspace_http_requests_total`                  | Counter   | method, path, status     | Total HTTP API requests             |
| `agentspace_http_request_duration_seconds`        | Histogram | method, path             | HTTP request duration               |

### Cron & Ingestion Metrics

| Metric                                          | Type      | Labels                        | Description                         |
| ----------------------------------------------- | --------- | ----------------------------- | ----------------------------------- |
| `agentspace_cron_executions_total`                | Counter   | agent_id, task_type, result   | Cron task executions                |
| `agentspace_ingestion_files_processed_total`      | Counter   | agent_id, result              | Ingestion files processed           |

## Useful PromQL Queries

**Total estimated spend by agent:**
```promql
sum(agentspace_llm_estimated_cost_dollars) by (agent_id)
```

**Cost per worker type (daily rate):**
```promql
sum by (worker_type) (rate(agentspace_worker_cost_dollars[1d]))
```

**Top 5 expensive workers:**
```promql
topk(5, sum by (worker_type, agent_id) (agentspace_llm_estimated_cost_dollars{tier="worker"}))
```

**Hourly spend rate by model:**
```promql
sum(rate(agentspace_llm_estimated_cost_dollars[1h])) by (agent_id, model) * 3600
```

**Token throughput:**
```promql
sum(rate(agentspace_llm_tokens_total[5m])) by (direction)
```

**MCP server health:**
```promql
agentspace_mcp_connections{state="connected"}
```

**Channel throughput by type:**
```promql
sum by (channel_type) (rate(agentspace_messages_received_total[5m]))
```

**Memory operation latency p99:**
```promql
histogram_quantile(0.99, sum by (operation, le) (rate(agentspace_memory_operation_duration_seconds_bucket[5m])))
```

**API latency by endpoint (p95):**
```promql
histogram_quantile(0.95, sum by (path, le) (rate(agentspace_http_request_duration_seconds_bucket[5m])))
```

**Active branches and workers:**
```promql
agentspace_active_branches
agentspace_active_workers
```

**Context overflow rate:**
```promql
sum by (agent_id, process_type) (rate(agentspace_context_overflow_total[1h]))
```

## Prometheus Scrape Config

```yaml
scrape_configs:
  - job_name: agentspace
    scrape_interval: 15s
    static_configs:
      - targets: ["localhost:9090"]
```

## Docker

Expose the metrics port alongside the API port:

```bash
docker run -d \
  --name agentspace \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -v agentspace-data:/data \
  -p 19898:19898 \
  -p 9090:9090 \
  ghcr.io/agentnxxt/agentspace:latest
```

The Docker image always includes metrics. For local builds without metrics, omit the `--features metrics` flag.
