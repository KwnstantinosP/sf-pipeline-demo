# Salesforce delta pipeline demo

DEV → SIT → UAT → PROD with automatic delta deploys, a PROD approval gate, and a hotfix lane.

```mermaid
flowchart LR
  F[feature/*] -- PR: check-only vs SIT --> D(develop)
  D -- auto delta deploy --> SIT[(SIT org)]
  D -- PR --> U(uat)
  U -- auto delta deploy --> UAT[(UAT org)]
  U -- release PR: check-only vs PROD --> M(main)
  H[hotfix/*] -- PR: check-only vs PROD --> M
  M -- validate, approve, quick deploy --> PROD[(PROD org)]
  M -. back-merge PR .-> U
  U -. back-merge PR .-> D
  D -. manual refresh .-> DEV[(DEV org)]
```

| Event | Workflow | What happens |
|---|---|---|
| PR into `develop` / `uat` / `main` | `pr-validate.yml` | Check-only deploy of the PR's delta to SIT / UAT / PROD, plus ESLint and Prettier on the changed files. Deletions need the `allow-destructive` label. |
| Merge into `develop` | `deploy-sandbox.yml` | Delta deploy to **SIT**, running only the tests for the changed classes |
| Merge into `uat` | `deploy-sandbox.yml` | Delta deploy to **UAT** with `RunLocalTests` if Apex changed |
| Merge into `main` | `deploy-prod.yml` | Validate against PROD → **approval** → quick deploy |
| Merge into `main` | `back-merge.yml` | Opens a `main → uat` PR if `uat` is missing anything |
| Merge into `uat` | `back-merge.yml` | Opens a `uat → develop` PR if `develop` is missing anything |
| Manual | `manual-deploy.yml` | Any ref to any org (DEV included), delta or full |

The DEV org is never deployed automatically, because people build there by hand. Bring it up to date from `develop` with *Manual Deploy* when the team chooses, for example at cycle start.

## Which branch to use

| Situation | Branch | Built in | Path to PROD |
|---|---|---|---|
| New work | `feature/*` from `develop` | DEV | develop → SIT → uat → UAT → release |
| Bug in this cycle's work, found in UAT (not in PROD yet) | `fix/*` from `uat` | DEV | uat → UAT → release |
| PROD is broken and can't wait for the release | `hotfix/*` from `main` | HOTFIX sandbox (refreshed from PROD) | main → PROD straight away, with approval |

- Nobody builds in UAT. Only the pipeline writes to it, so every UAT deploy checks that git is complete.
- If a `fix/*` turns out to be urgent, cherry-pick its commit onto a `hotfix/*` branch cut from `main`.
- `develop → uat` stays a deliberate, manual PR (the promotion). Every other sync is an automatic back-merge PR.

## How the delta works

- [sfdx-git-delta](https://github.com/scolladon/sfdx-git-delta) builds `package.xml` and `destructiveChanges.xml` from a git diff.
- The diff starts at the tag `deployed/<env>` (`sit`, `uat`, `prod`), which moves only after a successful deploy. If a deploy fails, its changes are still in the next delta.
- If an org has no tag yet, all of `force-app` is deployed.
- Tests:
  - No Apex in the delta: `NoTestRun`.
  - SIT: the changed test classes, plus `<Class>Test` / `<Class>_Test` / `<Class>TestClass` for each changed class. If any class has no match, or a trigger changed, it falls back to `RunLocalTests`.
  - UAT and PROD: `RunLocalTests` whenever the delta has Apex.

## Deleting components

Deleting a component's files in git deletes it from each org as the change reaches it. There is no hand-kept `destructiveChanges.xml` in the repo: the pipeline builds one in every run from the diff, then discards it. Two safeguards sit on top:

**1. Deletions need approval on the PR.** If a PR's delta deletes anything, *PR Validate* fails and lists the components. A reviewer checks the list and adds the label **`allow-destructive`** to the PR, which re-runs the check. Nothing is ever deleted by accident, for example by a bad merge or a retrieve that missed a file.

**2. Data is never deleted automatically.** Paths listed in [`.sgdignoreDestructive`](.sgdignoreDestructive) are left out of the deletion list even when their files are deleted in git:

| Kept in the org | Why |
|---|---|
| Custom objects (incl. custom settings, custom metadata types, platform events) | Deleting an object deletes its records |
| Custom fields | Deleting a field deletes its data |
| Custom metadata records | They are configuration data |
| Record types | Kept by sfdx-git-delta itself: the Metadata API can't delete them |

The run's summary lists these under *Deleted in git but kept in the org*. Remove them by hand in Setup once the data is backed up or no longer needed. Edit `.sgdignoreDestructive` to protect more paths (gitignore syntax).

**What happens when a deleted component is wanted back:**

| Situation | Result |
|---|---|
| Deleted and re-added before the change reached an org | That org sees no difference: nothing is deleted or redeployed |
| Deletion already deployed, then re-added in git | The next deploy creates it again; nothing is left over from the delete |
| A protected field was "deleted" in git, then re-added | It never left the org, so its data is untouched |

A deleted field that was **not** protected can be restored with its data from Setup → Object Manager → *Deleted Fields* for about 15 days. Re-deploying it instead creates a new, empty field.

## Code checks run on the PR, not on laptops

There are no git hooks. Nobody needs Node, npm, husky or lint-staged installed, and committing from the VS Code UI just works. The *Code quality* job in *PR Validate* checks only the files the PR changed:

| Check | Files | Effect |
|---|---|---|
| ESLint (`@salesforce/eslint-config-lwc` recommended) | LWC `.js` | Errors fail the PR |
| Prettier (Apex and XML plugins) | Anything Prettier can format | Report only, as warnings on the PR's *Files changed* tab |

Prettier stays report-only because files that were never formatted would be rewritten end to end. Set `STRICT_FORMAT: "true"` in `pr-validate.yml` after a one-time, team-agreed "format everything" commit.

To run the same checks locally (optional): `npm ci`, then `npx eslint <files>` and `npx prettier --check <files>`.

## Setup (about 30 minutes)

1. **Orgs.** Sign up for 4 free Developer Edition orgs at developer.salesforce.com/signup: DEV, SIT, UAT, PROD.
2. **Auth URLs.** For SIT, UAT and PROD:
   ```
   sf org login web --alias demo-sit
   sf org display --target-org demo-sit --verbose   # copy "Sfdx Auth Url"
   ```
3. **Repo.** Create a **public** repo on your personal account. Required reviewers on environments need a public repo or a paid plan. Push this folder, then create the `develop` and `uat` branches from `main`.
4. **Environments** (Settings → Environments). Each one gets a secret named `SFDX_AUTH_URL`:

   | Environment | Org | Protection |
   |---|---|---|
   | `DEV` | DEV | none, used only by *Manual Deploy* |
   | `SIT` | SIT | none |
   | `UAT` | UAT | none (or a reviewer) |
   | `PRODUCTION-VALIDATE` | PROD | none, used only for check-only runs |
   | `PRODUCTION` | PROD | **Required reviewers**: you or a colleague |

5. **Actions settings** (Settings → Actions → General): Workflow permissions = *Read and write*, and tick *Allow GitHub Actions to create and approve pull requests* (needed for back-merge PRs).
6. **Branch protection** on `develop`, `uat` and `main`: require a PR and the `validate` status check.
7. **Seed the tags.** Run *Manual Deploy* with `scope: full` and `validation_only: false` once each for DEV, SIT, UAT and PRODUCTION. GitHub doesn't start workflows for the first push into an empty repo, so this step is needed even though the first push contains code.
8. **Label.** Create the label `allow-destructive` (PR page → Labels → *Edit labels* → *New label*), used to approve deletions.

`scripts/setup/connect-orgs.sh` does steps 2 and the secrets part of step 4: it logs in to the orgs and copies each auth URL to the clipboard for pasting into GitHub.

## Demo script

**Scene 1: a feature flows to SIT on its own**
1. Branch `feature/demo-1` from `develop`, change the greeting in `DemoGreetingService.cls`, open a PR.
2. Show *PR Validate*. The job summary lists one class, and the tests run are only `DemoGreetingServiceTest`.
3. Merge. *Deploy to SIT / UAT* deploys just that class. Show the `deployed/sit` tag moving.

**Scene 2: SIT catches what never made it into git**
1. In the **DEV** org, create the field `Account.Demo_Tier__c` by hand.
2. Reference it in a class, but commit **only the class**.
3. The PR validation against SIT fails with `Variable does not exist: Demo_Tier__c`. In real life this would have surfaced in UAT, or in PROD.
4. Retrieve the field, commit it, push. The check turns green.

**Scene 3: promotion to UAT and PROD**
1. PR `develop → uat`, merge. UAT receives only what changed since its last deploy.
2. PR `uat → main` (or `release/cycleXX → main`), merge.
3. *Deploy to PRODUCTION*: validation runs, then the job waits. Show the approval screen, approve, and the quick deploy finishes in seconds.

**Scene 4: hotfix lane**
1. Branch `hotfix/demo-fix` from `main`, make a one-line change, PR into `main`. It is validated straight against PROD.
2. Merge and approve. PROD gets only that one file, even though `uat` and `develop` hold unreleased work.
3. Show the `main → uat` back-merge PR that opened automatically. Merge it: UAT gets the fix, and a `uat → develop` PR opens in turn. Merge that one too and SIT gets it.

**Scene 5: metadata-only change**
Change a page layout or a field description. The pipeline deploys it with `NoTestRun` in seconds.

**Scene 6: deletions are deliberate, data is protected**
1. Branch from `develop`, delete the `pipelineDemoBadge` LWC folder **and** `Pipeline_Demo_Tier__c.field-meta.xml`, open a PR.
2. *PR Validate* fails: "This PR deletes components from the org". The summary lists the LWC to be deleted, and the field under *Deleted in git but kept in the org*.
3. Add the `allow-destructive` label. The check re-runs and passes. Merge: SIT loses the LWC, but the field and its data stay.
4. Revert the PR. The LWC is deployed again, as if nothing happened.

## Things to call out to the team

- **Org drift.** The delta assumes each org matches its tag. Hand-made changes in SIT/UAT/PROD aren't tracked. Run *Manual Deploy* with `scope: full`, `validation_only: true` on a schedule to catch drift.
- **Profiles and permission sets** are deployed as the changed files only. Keep them small, or move to permission sets only.
- **PROD coverage.** PROD always runs `RunLocalTests` when Apex changes, so coverage rules stay exactly as they are today.
- **Quick deploy window.** A validation can only be quick-deployed for a limited time and only if nothing else deploys in between, so approve promptly.
- **Hotfix rule.** A hotfix ships only the files it changed, even while `uat` and `develop` hold unreleased work. Still cut it from `main` and build it in a sandbox refreshed from PROD, so it is tested against what PROD actually runs.
- **PRs opened by the back-merge job** don't trigger *PR Validate*, because GitHub doesn't run workflows on PRs opened with `GITHUB_TOKEN`. Close and reopen the PR, or switch the job to a GitHub App or PAT token. Once they are validated, a back-merge that carries deletions also needs the `allow-destructive` label.
- **Deletions.** A label approves code-level deletions; data (objects, fields, custom metadata records) is only ever removed by hand. Agree who may add the `allow-destructive` label.
