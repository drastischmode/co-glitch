<img width="1024" height="572" alt="image" src="https://github.com/user-attachments/assets/0d3cbccb-17b7-4cf1-a478-59569b6e493f" />

---

🛠️ co-glitch

The Swiss Army Knife for Autonomous AI Infrastructure & Development.
Client-First. Zero-Cost. Enterprise-Grade. Build locally, deploy globally.

https://img.shields.io/badge/Status-Stable%20(v1.0.3)-brightgreen?style=flat-square
https://img.shields.io/badge/Cost-0%E2%82%AC%20%2F%20month-blue?style=flat-square
https://img.shields.io/badge/Philosophy-Zero%20Trust%20%7C%20Tailnet--only-orange?style=flat-square
https://img.shields.io/badge/AI-4--Provider%20Fallback-purple?style=flat-square

co-glitch is your local, fully automated infrastructure platform. Inspired by comprehensive architectural concepts for autonomous AI systems, it packs the entire toolbox onto your Linux client (or optionally a VPS). It provides a hardened, offline-ready development environment that seamlessly bridges to your cloud stack when you're ready to deploy. No vendor lock-in, no hidden costs. Just a precise tool that works.

🧰 The Blades (What's inside)
Like a good Swiss Army Knife, co-glitch has the right tool for every problem. It covers both Runtime Infrastructure and Local Development.

⚙️ Runtime & AI
🔪 The AI Blade (4-Provider Fallback): OpenCode Zen → NVIDIA NIM → z.ai → Ollama (local). When one API hits a rate limit, the next takes over seamlessly.

🗡️ The Automation Blade: n8n for workflows and Forgejo for your local Git infrastructure.

👁️ The Monitoring Blade: Uptime Kuma, Dozzle, Beszel, and cAdvisor. Total visibility over CPU, RAM, logs, and health.

🛡️ The Security Blade: UFW, Fail2ban, and Tailscale. Zero-Trust by Default. All services are exclusively reachable via your private tailnet.

💻 The Development Workbench (Local-First)
🔧 The Database Blade: Supabase (Postgres) and Kong (API Gateway). A complete local backend for your AI applications, ready to be migrated to Supabase Cloud.

🚀 The Deployment Blade (Cloud-Ready): Pre-configured MCPs (Model Context Protocols) and CLI tools for GitHub, Vercel, Cloudflare, and Supabase.

Build locally using Forgejo and local Supabase instances.

Sync to GitHub when ready.

Deploy frontends to Vercel and manage edge logic via Cloudflare.

Push local database migrations directly to Supabase Cloud.

⚡ Quickstart (Unbox & Go)
Prerequisites: Linux (Arch, Ubuntu, Debian, Mint, etc.), 8 GB RAM (16 GB recommended for local Ollama models).

bash
# 1. Clone repo (Open the case)
git clone https://github.com/drastischmode/co-glitch.git && cd co-glitch

# 2. Run bootstrap script (Cleaning & Assembly)
./bootstrap.sh

# 3. Set API keys & Cloud Tokens (Sharpen the blades)
nano .env
# Enter keys for NVIDIA, ZAI, GITHUB_PAT, VERCEL_TOKEN, CLOUDFLARE_API_TOKEN, SUPABASE_KEYS

# 4. Activate Docker group (One-time)
newgrp docker

# 5. Join Tailnet (Lock the safety catch)
tailscale up

# 6. Start stack & check health
make up-client
make client-health
(Don't want to use make? Just run sudo bash scripts/client-bootstrap.sh.)

🏗️ The Engineering (Under the Hood)
The architectural concepts show that true stability comes from well-thought-out engineering. co-glitch implements this consistently:

Idempotency: All 12 shell scripts in the scripts/ folder can be run multiple times safely. They don't break things; they fix them.

4-State Health Checks: make client-health gives you exact status: healthy, running, unhealthy, or not-started. No blind guessing.

Strict Isolation: Separate Compose stacks for client, voice, and vps (optional).

Local-to-Cloud Parity: Develop with local Supabase and Forgejo, then push seamlessly to Supabase Cloud and GitHub using pre-configured environment variables and MCP servers.

Backup-Ready: The structure is designed so you can securely back up and restore your data and configurations (following the good old 3-2-1 rule).

📊 Status (Honest & Precise)
Swiss quality means: No empty promises.

✅ Stable (v1.0.3): Default onboarding path and extended stack (Postiz, Redis) successfully verified on a fresh Ubuntu 24.04 VM (Exit 0, no critical issues).

🛠️ Arch Support: Code is present and prepared for Arch. However, the fresh-machine test is still pending. (Feedback welcome!).

🚧 Voice Stack (Beta): Whisper/Piper configuration is present but not yet verified on a fresh VM.

🏢 VPS Stack (Optional): If you prefer to run this setup 24/7 on an Oracle Always Free server (ARM64) (as described in the concept), you'll find the necessary Compose files in the docker/vps folder.

📚 The Manual (Documentation)
01-QUICKSTART.md – Step-by-step onboarding

02-ARCHITECTURE.md – Resources, networks, ports (The blueprint)

03-TROUBLESHOOTING.md – First aid for problems

07-SECURITY.md – Hardening, secret rotation, zero trust

08-AI-PROVIDER.md – The fallback strategy in detail

09-VOICE-EXTENSIONS.md – Voice agent extensions

(New) 10-DEVELOPMENT.md – Local development workflow (GitHub, Vercel, Cloudflare, Supabase sync)

🤝 Contributing
co-glitch is a tool for the community.
Tested it on Arch? Verified the voice stack on a fresh machine? Or forged a new blade (MCP server / integration)?

Pull requests and issues are always welcome.

Built for maximum autonomy. 0 € software costs. No cloud dependency. Simply a damn good tool.
