# 09 - Jury Scenario

This document prepares the presentation of the project in front of a jury: a realistic scenario, a timed plan, a live demonstration script with a backup plan, the questions the jury is likely to ask, and the limits of the lab.

The plan assumes about 15 minutes of presentation followed by questions, with a live demonstration and screenshots as a backup. Adapt the timings to the actual format.

## 1. The scenario

A regional company runs its online catalog on a single web server. Two problems keep coming back:

- During promotions, the site becomes slow because one server cannot handle all the visitors.
- Each time the server is rebooted for maintenance, or crashes, the site goes offline.

**Mission:** design and demonstrate a web front end that spreads the load across several servers and keeps the site available when one of them fails, using only free tools.

**Solution presented:** an HAProxy load balancer in front of three Nginx web servers, with health checks, tested on virtual machines.

**Success criteria shown during the demonstration:**

| Criterion | How it is shown |
|---|---|
| Requests are distributed across the three servers | Browser refresh, `curl` loop, statistics page |
| The distribution can be changed | Algorithms and weights |
| A failed server is detected automatically | Dashboard turns red |
| Visitors keep being served during a failure | Live monitor stays on `200 OK` |
| The server returns to service by itself | Dashboard turns green again |
| Problems can be diagnosed methodically | Diagnostic ladder and exercises |

## 2. Architecture to present

![HAProxy network architecture](../diagrams/architecture.png)

| Machine | IP address | Role |
|---|---|---|
| `lb-haproxy` | 192.168.11.100 | Load balancer (frontend on port 80, statistics on 8404) |
| `web1` | 192.168.11.101 | Nginx web server |
| `web2` | 192.168.11.102 | Nginx web server |
| `web3` | 192.168.11.103 | Nginx web server |

Network: `192.168.11.0/24`, VMware bridged mode, static IP on every VM.

## 3. Timed plan (15 minutes)

| Time | Part | Content | Evidence |
|---|---|---|---|
| 0:00 - 2:00 | Problem and objectives | The scenario and the success criteria | Slide |
| 2:00 - 4:00 | Concepts and architecture | Load balancer, frontend, backend, high availability versus fault tolerance, the diagram | [01 - Concepts](01-concepts.md), [02 - Architecture](02-architecture.md) |
| 4:00 - 6:00 | Configuration | Frontend, backend, algorithms, health check parameters | [04 - HAProxy configuration](04-haproxy-config.md) |
| 6:00 - 9:00 | Demo 1 and 2 | Distribution and statistics page | Live |
| 9:00 - 12:00 | Demo 3 | Failure and automatic recovery of a server | Live |
| 12:00 - 13:30 | Method | The diagnostic ladder and one exercise as an example | [07 - Troubleshooting](07-troubleshooting.md), [08 - Exercises](08-exercises.md) |
| 13:30 - 15:00 | Limits and conclusion | Lab versus production, improvements | Slide |

## 4. Before the presentation

Run these checks the day before and again just before presenting.

On `lb-haproxy`:

```bash
systemctl is-active haproxy
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock | cut -d, -f1,2,18
for i in $(seq 1 6); do curl -s -I http://192.168.11.100 | grep -i x-served-by; done
```

On `web1`, `web2` and `web3`: `systemctl is-active nginx` must answer `active`, and `sudo ufw status` must answer `inactive`.

Checklist:

- [ ] The four VMs are running and all three servers are `UP` in the dashboard
- [ ] The active configuration is the final one (`configs/haproxy/haproxy-final.cfg`)
- [ ] One terminal open on `lb-haproxy`, one console already logged in on `web2`
- [ ] The statistics page open in a browser (`http://192.168.11.100:8404/stats`) and already logged in
- [ ] A browser tab open on `http://192.168.11.100`
- [ ] The screenshots folder open, ready for the backup plan
- [ ] Terminal font enlarged so the room can read it

## 5. Live demonstration script

### Demo 1: distribution (about 1.5 minutes)

Say: "A visitor only knows one address. Watch which server answers."

1. In the browser, refresh `http://192.168.11.100` several times. The name displayed (`web1`, `web2`, `web3`) changes.
2. In the terminal, show the count:

   ```bash
   for i in $(seq 1 12); do curl -s -I http://192.168.11.100 | grep -i x-served-by; done | sort | uniq -c
   ```

   Expected: 4, 4 and 4. Explain that each server's name is added to the response by Nginx, so the answer can be traced.

### Demo 2: statistics page (about 1.5 minutes)

Say: "HAProxy confirms from its own point of view where it sent the requests."

1. Show the `web_servers` table in the dashboard: sessions per server, status, last health check (`L7OK/200`).
2. Show the log and count the requests per server:

   ```bash
   sudo tail -n 12 /var/log/haproxy.log | grep -o 'web_servers/web[0-9]' | sort | uniq -c
   ```

3. Mention the algorithms and show the three lines that differ in the configuration files: `balance roundrobin`, `balance leastconn`, and `weight 3/2/1`.

Optional, only if rehearsed: change weights at runtime without editing any file, then restore them.

```bash
echo "set weight web_servers/web1 3" | sudo socat stdio /run/haproxy/admin.sock
echo "set weight web_servers/web2 2" | sudo socat stdio /run/haproxy/admin.sock
for i in $(seq 1 12); do curl -s -I http://192.168.11.100 | grep -i x-served-by; done | sort | uniq -c
echo "set weight web_servers/web1 1" | sudo socat stdio /run/haproxy/admin.sock
echo "set weight web_servers/web2 1" | sudo socat stdio /run/haproxy/admin.sock
```

### Demo 3: failure and recovery (about 3 minutes)

Say: "A server crashes during the promotion. Watch what the visitors see."

1. Start the live monitor on `lb-haproxy`:

   ```bash
   watch -n 1 'curl -s -I --max-time 2 http://192.168.11.100 | grep -iE "HTTP/|x-served-by"'
   ```

   It shows `200 OK` and the three server names in rotation.
2. On the `web2` console, simulate the crash:

   ```bash
   sudo systemctl stop nginx
   ```

3. Within a few seconds the dashboard shows `web2` in red. The monitor now shows only `web1` and `web3`, still with `200 OK`.
4. Show what HAProxy recorded:

   ```bash
   sudo grep -E "WARNING.*web2 is (DOWN|UP)" /var/log/haproxy.log | tail -n 2 | cut -c1-140
   ```

   The reason given is `Connection refused`.
5. Repair, and show the automatic recovery:

   ```bash
   sudo systemctl start nginx
   ```

   After a few seconds `web2` turns green and returns into the rotation, without any change to HAProxy.

Key points to say out loud:

- Detection takes about `fall 3` times `inter 2s`, so roughly 6 seconds.
- With `retries 3` and `option redispatch`, refused connections are retried on another server. In the measurement made during the exercises, 0 of 129 requests failed with this setting, against 2 of 111 without it. The sample is small, so present it as an illustration.
- The load balancer itself remains a single point of failure, which is the main limit of the lab.

### If something goes wrong during the demo

| Problem | What to do |
|---|---|
| Dashboard does not open | Use `echo "show stat" \| sudo socat stdio /run/haproxy/admin.sock \| cut -d, -f1,2,18` in the terminal |
| A VM does not answer | Show the matching screenshot and continue |
| `web2` does not come back after the restart | Wait about 10 seconds. If still red, run `curl -I http://192.168.11.102` and `systemctl status nginx` on `web2`, and use it as a live diagnosis |
| Complete failure of the lab | Switch to the screenshots listed below |

### Backup plan: screenshots

| Topic | Screenshots |
|---|---|
| VMs and network | `01-haproxy-and-web-server-vm-created.png`, `02-web1-ping-from-host.png`, `07-lb-connectivity-to-web-servers.png` |
| Distribution | `12-roundrobin-test.png`, `16-weighted-roundrobin-test.png`, `17-haproxy-logs-distribution.png`, `19-haproxy-stats-dashboard.png` |
| Failure and recovery | `22-web2-down-dashboard.png`, `23-web2-down-watch.png`, `24-web2-down-up-logs.png`, `25-web2-recovered-dashboard.png` |
| Application-level failure | `26-web2-403-port-open.png`, `27-web2-l7sts-403-dashboard.png` |
| Diagnosis | `29-diagnostic-toolkit.png`, `34-exercise3-diagnosis.png`, `37-exercise4-tcpdump-firewall.png` |

## 6. Questions the jury may ask

**What is the difference between a reverse proxy and a load balancer?**
A reverse proxy stands in front of servers and relays requests. A load balancer is a reverse proxy that also chooses which server receives each request, according to an algorithm and the health of the servers. HAProxy does both.

**Why HAProxy?**
It is free and open source, mature, very efficient, works at layer 4 and layer 7, and includes health checks, logging, a statistics page and a runtime API.

**What happens if the load balancer itself fails?**
In this lab the service goes down, because it is a single point of failure. In production there are two HAProxy nodes with Keepalived, which moves a virtual IP address to the surviving node.

**How does HAProxy detect a failed server?**
Through health checks: every `inter` (2 seconds) it sends `GET /`. After `fall` (3) failures in a row the server is marked down. After `rise` (2) successes it is marked up again. A TCP check only tests the port, while an HTTP check also verifies that the application answers with the expected status.

**Why use an HTTP check instead of a TCP check?**
A server can keep its port open while its application is broken. In the bonus test, `web2` returned `403` with port 80 open: a TCP check would have kept it in service, while the HTTP check marked it down (`L7STS/403`).

**What is the difference between Round Robin and Least Connections?**
Round Robin sends requests in turn, regardless of the load. Least Connections sends each request to the server with the fewest active connections, which suits long connections such as downloads or uploads. For short requests the two behave almost the same.

**How do you take a server out for maintenance without cutting users?**
Put it in drain mode (`set server web_servers/web3 state drain`, or `weight 0`). It stops receiving new requests, existing ones finish, and it can then be updated safely. Runtime changes live only in memory, so a lasting change must also be written in the configuration file.

**What happens to active connections when the configuration is reloaded?**
A reload starts a new HAProxy process that takes over new connections, while the old process finishes the existing ones. Ubuntu's reload also checks the configuration first and keeps the old one if the new one is invalid.

**How would you add a fourth web server?**
Create the server, add one `server web4 <ip>:80 check` line to the backend, validate with `haproxy -c`, then reload.

**What about user sessions, for example a shopping cart?**
This lab serves static pages, so sessions are not an issue. For an application with sessions, either share the session data between servers or enable persistence in HAProxy (cookie-based or by source address). That was not implemented here.

**What about HTTPS?**
The lab uses plain HTTP. In production HAProxy would terminate TLS on port 443 with a certificate, and could redirect HTTP to HTTPS.

**What did you find difficult or learn from a mistake?**
A real example from the exercises: in the tuning measurement, my first analysis counted only `503` errors and found none. The failed requests were actually logged as `000` (no usable response). Counting every response that is not `200` showed the real result. The lesson: verify that the measurement itself is correct before drawing conclusions.

**What is the difference between this lab and production?**

| Aspect | This lab | Production |
|---|---|---|
| Load balancer | One HAProxy VM | Two nodes with Keepalived and a virtual IP |
| Protocol | HTTP only | HTTPS with certificates |
| Network | One flat network | Separated public and private networks, firewalls allowing only the load balancer to reach the backends |
| Servers | Three VMs on one host | Servers spread across hosts or zones |
| Monitoring | Manual commands and the statistics page | Metrics, dashboards and alerts |
| Deployment | Manual configuration and cloning | Automated provisioning and version-controlled configuration |

## 7. Limits and possible improvements

| Limit | Improvement |
|---|---|
| Single load balancer | Second HAProxy node with Keepalived (VRRP) and a virtual IP |
| HTTP only | TLS termination on port 443 |
| Backends reachable by anyone | Firewall rules that allow port 80 only from the load balancer |
| Statistics page exposed on the network | Restrict it to a management network and protect it with HTTPS |
| Manual observation | Export metrics to Prometheus and Grafana, centralize logs |
| Manual configuration | Automate with Ansible and keep the configuration in Git |
| No session persistence | Cookie-based or source-based persistence if the application needs it |

## 8. Final advice

- Rehearse the demo at least twice, with a timer.
- Know why each parameter exists (`inter`, `fall`, `rise`, `retries`, `weight`), not only what it does.
- When you do not know an answer, say what you would check and with which command. The diagnostic method is part of what is being assessed.
- Be honest about the limits of the lab, because naming them shows that you understand production.
