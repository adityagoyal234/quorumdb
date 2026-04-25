<div align="center">

# QuorumDB

### A Production-Grade Dynamo-Style Storage System

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [API Reference](#-api-reference)
- [Configuration](#️-configuration)
- [Testing](#-testing)
- [Benchmarks](#-benchmarks)
- [Project Structure](#-project-structure)
- [Technical Deep Dive](#-technical-deep-dive)
- [Contributing](#-contributing)
- [Acknowledgments](#-acknowledgments)

---

## 🎯 Overview

**QuorumDB** is a distributed key-value store designed for scenarios requiring:

- **High Availability** - The system remains operational even when nodes fail
- **Horizontal Scalability** - Add more nodes to handle increased load
- **Low Latency** - Optimized for fast reads and writes
- **Eventual Consistency** - With tunable consistency levels for flexibility

---

## ✨ Features

### Core Distributed Systems Features

| Feature | Description |
|---------|-------------|
| **Consistent Hashing** | Data partitioning using a 64-bit hash ring with virtual nodes |
| **Replication** | Configurable N-way replication across preference list nodes |
| **Tunable Consistency** | Quorum-based operations (W + R > N guarantees) |
| **Gossip Protocol** | Peer-to-peer failure detection and membership dissemination |
| **Hinted Handoff** | Temporary storage for unavailable nodes |
| **Read Repair** | Automatic consistency healing during read operations |
| **Vector Clocks** | Causality tracking for conflict detection |
| **Last-Write-Wins** | Timestamp-based conflict resolution |

### Storage Engine (Bitcask Model)

| Feature | Description |
|---------|-------------|
| **Append-Only Writes** | All writes are sequential appends for durability |
| **In-Memory Index** | O(1) key lookups with single disk seek |
| **CRC Checksums** | Data integrity verification |
| **Compaction** | Space reclamation from deleted/overwritten keys |
| **Crash Recovery** | Automatic index rebuild from log on restart |

### Operations & Management

| Feature | Description |
|---------|-------------|
| **RESTful API** | Simple HTTP/JSON interface |
| **Admin Endpoints** | Cluster status, statistics, ring visualization |
| **Graceful Shutdown** | Clean shutdown with data persistence |
| **Configurable** | CLI flags, config files, or environment variables |

## 🏗 Architecture

### High-Level System Design

```
                                    ┌─────────────────┐
                                    │    Client App   │
                                    └────────┬────────┘
                                             │
                                             │ HTTP/REST
                                             ▼
                    ┌────────────────────────────────────────────┐
                    │              Load Balancer                  │
                    └────────────────────────┬───────────────────┘
                                             │
              ┌──────────────────────────────┼──────────────────────────────┐
              │                              │                              │
              ▼                              ▼                              ▼
    ┌─────────────────┐            ┌─────────────────┐            ┌─────────────────┐
    │     Node 1      │◄──────────►│     Node 2      │◄──────────►│     Node 3      │
    │   (Coordinator) │   Gossip   │   (Replica)     │   Gossip   │   (Replica)     │
    ├─────────────────┤            ├─────────────────┤            ├─────────────────┤
    │ ┌─────────────┐ │            │ ┌─────────────┐ │            │ ┌─────────────┐ │
    │ │  Hash Ring  │ │            │ │  Hash Ring  │ │            │ │  Hash Ring  │ │
    │ └─────────────┘ │            │ └─────────────┘ │            │ └─────────────┘ │
    │ ┌─────────────┐ │            │ ┌─────────────┐ │            │ ┌─────────────┐ │
    │ │  Bitcask    │ │            │ │  Bitcask    │ │            │ │  Bitcask    │ │
    │ │  Storage    │ │            │ │  Storage    │ │            │ │  Storage    │ │
    │ └─────────────┘ │            │ └─────────────┘ │            │ └─────────────┘ │
    └─────────────────┘            └─────────────────┘            └─────────────────┘
```

### Request Flow

```
┌──────────┐     ┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Client  │────►│ Coordinator │────►│  Hash Ring   │────►│ Preference  │
│          │     │    Node     │     │   Lookup     │     │    List     │
└──────────┘     └─────────────┘     └──────────────┘     └─────────────┘
                                                                  │
                        ┌─────────────────────────────────────────┤
                        │                                         │
                        ▼                                         ▼
                ┌───────────────┐                        ┌───────────────┐
                │   Replicate   │                        │   Replicate   │
                │   to Node A   │                        │   to Node B   │
                └───────────────┘                        └───────────────┘
                        │                                         │
                        └─────────────┬───────────────────────────┘
                                      │
                                      ▼
                              ┌───────────────┐
                              │ Quorum Check  │
                              │  (W acks)     │
                              └───────────────┘
                                      │
                                      ▼
                              ┌───────────────┐
                              │    Response   │
                              │   to Client   │
                              └───────────────┘
```

### Consistent Hashing Ring

```
                           0
                           │
                    ┌──────┴──────┐
                   /               \
                  /                 \
           N3-v2 ●                   ● N1-v1
                /                     \
               /                       \
        N2-v1 ●                         ● N2-v2
             │                           │
             │      ┌───────────┐        │
             │      │   Ring    │        │
             │      │  64-bit   │        │
             │      │   Hash    │        │
             │      │   Space   │        │
             │      └───────────┘        │
             │                           │
        N1-v2 ●                         ● N3-v1
              \                         /
               \                       /
                \                     /
                 ● N1-v3       N2-v3 ●
                  \                 /
                   \               /
                    └──────┬──────┘
                           │
                          2⁶⁴
```

---

## 📡 API Reference

### Key-Value Operations

#### Store a Value

```http
PUT /kv/{key}
Content-Type: application/json

{
  "value": "your data here",
  "consistency": "quorum"  // optional: "one", "quorum", "all"
}
```

**Response (200 OK):**
```json
{
  "status": "ok",
  "key": "mykey",
  "version": 1702934567890123456
}
```

#### Retrieve a Value

```http
GET /kv/{key}?consistency=quorum
```

**Response (200 OK):**
```json
{
  "key": "mykey",
  "value": "your data here",
  "version": 1702934567890123456
}
```

**Response (404 Not Found):**
```json
{
  "error": "Not Found",
  "code": 404,
  "message": "key not found"
}
```

#### Delete a Value

```http
DELETE /kv/{key}
```

**Response (200 OK):**
```json
{
  "status": "ok",
  "key": "mykey"
}
```

### Admin Operations

#### Cluster Status

```http
GET /admin/status
```

**Response:**
```json
{
  "node_id": "node1",
  "address": "127.0.0.1:8001",
  "uptime": "2h 15m 30s",
  "keys": 15420,
  "storage": {
    "active_keys": 15420,
    "deleted_keys": 123,
    "data_file_size_bytes": 52428800,
    "total_reads": 1250000,
    "total_writes": 450000
  },
  "cluster": {
    "size": 3,
    "nodes": [
      {"id": "node1", "address": "127.0.0.1:8001", "state": "alive"},
      {"id": "node2", "address": "127.0.0.1:8002", "state": "alive"},
      {"id": "node3", "address": "127.0.0.1:8003", "state": "alive"}
    ]
  }
}
```

#### Ring Information

```http
GET /admin/ring
```

#### Storage Statistics

```http
GET /admin/stats
```

#### List All Keys

```http
GET /admin/keys
```

#### Health Check

```http
GET /health
```

### Consistency Levels

| Level | Replicas Required | Use Case |
|-------|-------------------|----------|
| `one` | 1 | Maximum availability, single-node testing |
| `quorum` | ⌈(N+1)/2⌉ | Balanced consistency/availability (default) |
| `all` | N | Maximum consistency, lowest availability |

---

## ⚙️ Configuration

### Command Line Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--node-id` | string | hostname | Unique identifier for this node |
| `--address` | string | 127.0.0.1 | IP address to bind to |
| `--port` | int | 8080 | HTTP API port |
| `--gossip-port` | int | 7946 | UDP port for gossip protocol |
| `--data-dir` | string | ./data | Directory for persistent storage |
| `--seeds` | string | "" | Comma-separated seed node addresses |
| `--replication` | int | 3 | Replication factor (N) |
| `--read-quorum` | int | 2 | Read quorum (R) |
| `--write-quorum` | int | 2 | Write quorum (W) |
| `--vnodes` | int | 150 | Virtual nodes per physical node |
| `--config` | string | "" | Path to JSON config file |
| `--version` | bool | false | Show version and exit |

### Configuration File (JSON)

```json
{
  "node_id": "production-node-1",
  "address": "10.0.1.10",
  "port": 8080,
  "gossip_port": 7946,
  "data_dir": "/var/lib/quorumdb",
  "seed_nodes": [
    "10.0.1.11:7946",
    "10.0.1.12:7946"
  ],
  "max_file_size": 104857600,
  "sync_writes": false,
  "compact_interval": 300,
  "replication_factor": 3,
  "read_quorum": 2,
  "write_quorum": 2,
  "virtual_nodes": 150
}
```

### Environment Variables

All config options can also be set via environment variables with the `QUORUMDB_` prefix:

```bash
export QUORUMDB_NODE_ID=node1
export QUORUMDB_PORT=8001
export QUORUMDB_REPLICATION_FACTOR=3
```

---

## 🧪 Testing

### Unit Tests

```bash
# Run all unit tests
make test

# Run with verbose output
go test -v ./internal/...

# Run specific package tests
go test -v ./internal/storage/...
go test -v ./internal/ring/...
```

### Integration Tests

```bash
# Requires building first
make build

# Run integration tests
make test-integration

# Or manually
go test -v -tags=integration ./test/integration/...
```

### Test Coverage

```bash
make coverage

# View coverage report in browser
open coverage.html
```

### Load Testing

```bash
# Built-in load tester
make load-test

# Custom parameters
go run test/load/benchmark.go \
  -target=http://localhost:8001 \
  -requests=10000 \
  -concurrency=50 \
  -write-ratio=0.3
```

### Chaos Testing

```bash
# Start cluster
make cluster

# Write some data
for i in {1..100}; do
  curl -X PUT "http://localhost:8001/kv/key$i" -d "{\"value\":\"value$i\"}"
done

# Kill a node (simulates failure)
kill $(lsof -t -i:8002)

# Verify reads still work (quorum of 2 from remaining nodes)
curl http://localhost:8001/kv/key50

# Restart killed node
./bin/quorumdb --node-id=node2 --port=8002 --gossip-port=7002 \
  --data-dir=./data/node2 --seeds=127.0.0.1:7001
```

---


## 📁 Project Structure

```
quorumdb/
├── cmd/
│   └── quorumdb/
│       └── main.go                 # Application entry point
│
├── internal/
│   ├── api/
│   │   ├── server.go               # HTTP server setup
│   │   ├── handlers.go             # Request handlers
│   │   └── middleware.go           # Logging, CORS, recovery
│   │
│   ├── config/
│   │   └── config.go               # Configuration management
│   │
│   ├── gossip/
│   │   ├── membership.go           # Cluster membership list
│   │   ├── detector.go             # Failure detection
│   │   └── protocol.go             # UDP gossip protocol
│   │
│   ├── replication/
│   │   ├── coordinator.go          # Distributed operations
│   │   ├── quorum.go               # Quorum management
│   │   └── handoff.go              # Hinted handoff
│   │
│   ├── ring/
│   │   ├── hash_ring.go            # Consistent hashing
│   │   └── vnode.go                # Virtual nodes
│   │
│   ├── storage/
│   │   ├── engine.go               # Storage interface
│   │   ├── bitcask.go              # Bitcask implementation
│   │   ├── index.go                # In-memory index
│   │   └── bitcask_test.go         # Unit tests
│   │
│   └── versioning/
│       ├── vector_clock.go         # Vector clock operations
│       └── resolver.go             # Conflict resolution
│
├── pkg/
│   └── types/
│       └── types.go                # Shared types & interfaces
│
├── test/
│   ├── integration/
│   │   └── cluster_test.go         # Multi-node tests
│   └── load/
│       └── benchmark.go            # Load testing tool
│
├── scripts/
│   ├── start_cluster.sh            # Start 3-node cluster
│   └── stop_cluster.sh             # Stop cluster
│
├── go.mod                          # Go module definition
├── go.sum                          # Dependency checksums
├── Makefile                        # Build automation
├── config.example.json             # Example configuration
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🔬 Technical Deep Dive

### Consistent Hashing Algorithm

```go
// Hash function: MurmurHash3 (64-bit)
func hash(key string) uint64 {
    h := murmur3.New64()
    h.Write([]byte(key))
    return h.Sum64()
}

// Virtual nodes for even distribution
for i := 0; i < virtualNodes; i++ {
    vnodeKey := fmt.Sprintf("%s#vnode%d", nodeID, i)
    ring.AddToken(hash(vnodeKey), nodeID)
}

// Key lookup: binary search for successor
func GetNode(key string) string {
    h := hash(key)
    idx := sort.Search(len(tokens), func(i int) bool {
        return tokens[i].Hash >= h
    })
    return tokens[idx % len(tokens)].NodeID
}
```

### Quorum Mathematics

For a replication factor of **N = 3**:

| Configuration | Guarantees |
|---------------|------------|
| W=2, R=2 | Strong consistency (W + R > N) |
| W=1, R=1 | Eventual consistency (faster, less safe) |
| W=3, R=1 | Write-heavy workload optimization |
| W=1, R=3 | Read-heavy workload optimization |

### Bitcask File Format

```
┌────────────┬───────────┬─────────┬───────────┬─────────┬─────────┬─────────┐
│  CRC32     │ Timestamp │ Key Len │ Value Len │ Deleted │   Key   │  Value  │
│  (4 bytes) │ (8 bytes) │(4 bytes)│ (4 bytes) │(1 byte) │(N bytes)│(M bytes)│
└────────────┴───────────┴─────────┴───────────┴─────────┴─────────┴─────────┘
```

### Gossip Protocol State Machine

```
         ┌─────────────────────────────────────┐
         │                                     │
         ▼                                     │
    ┌─────────┐    5s timeout    ┌─────────┐   │
    │  ALIVE  │─────────────────►│ SUSPECT │   │
    └─────────┘                  └─────────┘   │
         ▲                            │        │
         │                            │ 30s    │
         │                            │timeout │
         │  Heartbeat                 ▼        │
         │  received             ┌────────┐    │
         └───────────────────────│  DEAD  │────┘
                                 └────────┘
                                      │
                                      │ Removed from
                                      │ hash ring
                                      ▼
```

---


## Acknowledgments

- **[Amazon Dynamo Paper](https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf)** - The foundational research that inspired this project
- **[Bitcask Paper](https://riak.com/assets/bitcask-intro.pdf)** - Storage engine design inspiration
- **[Consistent Hashing](https://www.cs.princeton.edu/courses/archive/fall09/cos518/papers/chash.pdf)** - Karger et al.'s seminal work
- **[SWIM Protocol](https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf)** - Gossip-based failure detection

---



