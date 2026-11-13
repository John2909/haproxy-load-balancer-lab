# 01 - Essential Concepts

This document introduces the vocabulary used throughout the lab: load balancing, reverse proxy, frontend, backend, high availability and fault tolerance.

## 1. Load balancing

Load balancing means distributing incoming requests across several identical servers. An analogy is a supermarket with several checkouts and one person at the entrance who directs each customer to a checkout.

Goals:

- **Capacity:** several servers handle more requests than one.
- **Availability:** if one server fails, the others keep serving.
- **Fair use of resources:** no server is overloaded while others are idle.

## 2. Reverse proxy

A reverse proxy is an intermediary placed in front of the servers. The client talks to the proxy and never directly to the servers. The proxy receives the request, forwards it to a server, then returns the response to the client.

A load balancer is a reverse proxy that also decides **which** server receives each request. HAProxy plays both roles.

## 3. Frontend and backend (HAProxy vocabulary)

| Term | Meaning |
|---|---|
| **Frontend** | The entry point. It defines the address and port HAProxy listens on (for example port 80) and where the traffic goes next |
| **Backend** | The pool of real servers that process the requests, with the balancing algorithm and the health checks |

In HAProxy, "backend" does not mean the back-end of a web application. It means the group of servers behind the load balancer.

```
Client --> Frontend (HAProxy) --> Backend --> web1 | web2 | web3
```

## 4. High availability and fault tolerance

| Term | Meaning | In this lab |
|---|---|---|
| **High availability (HA)** | The goal: the service stays reachable even if a component fails, by removing single points of failure | The three web servers are redundant, but `lb-haproxy` is still a single point of failure |
| **Fault tolerance** | The mechanism: the system keeps working correctly when an element fails | HAProxy detects a dead web server with health checks and stops sending it traffic |

In one sentence: high availability is the objective (the service is always reachable), and fault tolerance is how the system absorbs a failure to reach it.

In production, the load balancer itself is doubled (for example two HAProxy nodes with Keepalived and a virtual IP).

## 5. Balancing algorithms (preview)

| Algorithm | How it chooses a server | Best suited for |
|---|---|---|
| Round Robin | Each server in turn | Short, similar requests on equal servers |
| Weighted Round Robin | Each server in turn, in proportion to its weight | Servers of different capacity |
| Least Connections | The server with the fewest active connections | Long or uneven connections |

They are configured and tested in [04 - HAProxy configuration](04-haproxy-config.md).

## 6. Layer 4 and layer 7

HAProxy can work at two levels:

| Mode | Directive | What HAProxy sees |
|---|---|---|
| Layer 4 (TCP) | `mode tcp` | Only connections: addresses and ports |
| Layer 7 (HTTP) | `mode http` | Requests, headers, URLs and status codes |

This lab uses `mode http`, which allows HTTP health checks and readable logs.

## 7. Next step

- [02 - Lab architecture](02-architecture.md)
