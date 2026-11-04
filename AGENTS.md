# Instructions for AI agents

This repo holds infrastructure code for the homelab. All knowledge, decisions, and playbooks live in the [handbook](https://github.com/ssaav5-ai-labs/handbook). Read `playbooks/RUNNING.md` there before running any playbook.

Before acting here, read:
- The relevant `docs/domains/proxmox/` pages in the handbook
- Accepted ADRs in `docs/decisions/` in the handbook
- Open questions in `docs/open-questions/` in the handbook

Never commit secrets, tokens, real public IPs, or real hostnames.

Never render, exec into or print anything that decrypts secrets (KSOPS, sops, the Argo CD repo-server). Debug sync failures from the Application status only. You may merge your own PRs with gh pr merge --squash once all required checks are green; never merge with failing or pending checks.