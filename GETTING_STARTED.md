# Getting Started with GitHub & This Project — No Experience Required

This guide assumes you have **never used GitHub, git, or a CI/CD pipeline before**. Every step says exactly what to click and where files end up. Skip nothing your first time through, even if a step feels obvious.

**Tools you'll be using:** GitHub Desktop, Visual Studio Code (with GitHub Copilot), and a free GitHub.com account.

---

## Part 1 — Accounts and Tools

### Step 1: Create a GitHub account (skip if you already have one)
1. Go to [github.com](https://github.com) and click **Sign up**.
2. Follow the prompts (email, username, password). Verify your email when prompted.
3. This account is where all your project files, history, and documentation will live online — think of it as cloud storage that also remembers every past version of every file.

### Step 2: Install GitHub Desktop (skip if already installed)
1. Go to [desktop.github.com](https://desktop.github.com) and download the Windows installer.
2. Run it. It installs automatically — no wizard steps to click through.
3. When it opens, click **Sign in to GitHub.com** and log in with the account from Step 1.

### Step 3: Install Visual Studio Code (skip if already installed)
1. Go to [code.visualstudio.com](https://code.visualstudio.com) and download the Windows installer.
2. Run the installer, accept the defaults, and let it finish.
3. GitHub Copilot (which you mentioned you already have) will appear as an icon in VS Code's left sidebar once signed in — if not yet signed in, click the Copilot icon and follow the sign-in prompt.

**Checkpoint:** you should now have GitHub.com (account), GitHub Desktop (app), and VS Code (app) all installed and signed in.

---

## Part 2 — Getting the Project Files onto Your Computer

### Step 4: Download the project files
1. Download `soc-home-lab.tar.gz` (provided in this chat).
2. In File Explorer, navigate to `E:\PePesLab-SOC 2.0\`. If that folder doesn't exist yet, create it (right-click → New → Folder, name it `PePesLab-SOC 2.0`).
3. Extract the downloaded file into that folder. Windows can extract `.tar.gz` with a right-click **Extract All** in recent versions; if that option doesn't appear, install [7-Zip](https://www.7-zip.org/) (free) and use its right-click **Extract Here** instead.
4. After extracting, confirm you now have a folder at exactly:
   ```
   E:\PePesLab-SOC 2.0\soc-home-lab
   ```
   containing folders named `docs`, `configs`, `screenshots`, `.github`, and files like `README.md`.

### Step 5: Create the empty repository on GitHub.com
1. Go to [github.com/new](https://github.com/new) (make sure you're logged in).
2. **Repository name:** `soc-home-lab`
3. **Owner:** your account (`PePeLePuu0610`)
4. Leave it set to whatever visibility you want (Public shows it as a portfolio piece; Private keeps it hidden until you're ready).
5. **Important:** do **not** check "Add a README file" or add a `.gitignore` or license — you already have these in your extracted folder, and letting GitHub create its own copies will cause a conflict later.
6. Click **Create repository**. You'll land on an empty repo page with setup instructions — you can ignore those, GitHub Desktop will handle it.

**Checkpoint:** you have an empty repo on GitHub.com and a full folder of files on your E: drive. Nothing is connected yet — that's Part 3.

---

## Part 3 — Connecting Your Files to GitHub

### Step 6: Add the local folder as a repository in GitHub Desktop
1. Open GitHub Desktop.
2. Menu bar → **File → Add local repository**.
3. Click **Choose...** and browse to `E:\PePesLab-SOC 2.0\soc-home-lab`, select it, click **Select Folder**.
4. GitHub Desktop will say this folder is not yet a git repository and offer to **create a repository** here — click that link/button.
5. You'll briefly see a "Create a Repository" form pre-filled with the folder — just click **Create Repository** at the bottom.

### Step 7: Make your first commit
A "commit" is a saved snapshot of your files with a note describing what changed — this is the core habit of using git.
1. In GitHub Desktop, you'll now see a list of every file in the folder under **Changes**, each with a checkmark (this means "include this file in the snapshot").
2. In the box at the bottom left, type a summary, e.g. `Initial commit: docs site, CI/CD pipeline, docker-compose starters`.
3. Click the blue **Commit to main** button.

### Step 8: Publish (push) to GitHub.com
1. At the top of the GitHub Desktop window, click **Publish repository**.
2. Confirm the name is `soc-home-lab` and it's set to publish under your account, matching the empty repo you created in Step 5.
3. Choose Public or Private (should match what you picked in Step 5, though it isn't critical).
4. Click **Publish repository**.
5. Wait for the upload to finish — for this project's size, it should take well under a minute.

**Checkpoint:** refresh your repo's page on GitHub.com (`github.com/PePeLePuu0610/soc-home-lab`) — you should see every file and folder listed there now.

---

## Part 4 — Watching the CI/CD Pipeline Run

"CI/CD" stands for **Continuous Integration / Continuous Deployment** — plain-language version: *every time you save changes to GitHub, a robot automatically checks your work, and if it passes, automatically publishes your documentation website.* You don't run anything manually.

### Step 9: Watch your first pipeline run
1. On your repo's GitHub.com page, click the **Actions** tab near the top.
2. You'll see a workflow run already in progress or completed, named after your commit message (e.g. "Initial commit: docs site...").
3. Click on it. You'll see two workflows listed: **Docs CI** and **Docs Deploy**.
4. Click into **Docs CI** — you'll see several jobs (Lint Markdown, Check Links, Build Docs Site, Validate Docker Compose Files, Scan for Accidentally Committed Secrets) each with a green checkmark once finished, or a red X if something failed.
5. Click into **Docs Deploy** — this one publishes your documentation website. A green checkmark means your site is now live.

### Step 10: Turn on GitHub Pages (one-time setup)
The deploy workflow publishes your site to a special branch called `gh-pages`, but you need to tell GitHub to actually serve it as a website — this is a one-time setting.
1. On your repo page, click **Settings** (top right area of the repo, not your account settings).
2. In the left sidebar, click **Pages**.
3. Under **Build and deployment → Source**, choose **Deploy from a branch**.
4. Under **Branch**, choose `gh-pages` and folder `/ (root)`, then click **Save**.
5. Wait 1-2 minutes, then refresh — GitHub will show you the live URL, which will be:
   ```
   https://PePeLePuu0610.github.io/soc-home-lab/
   ```

**Checkpoint:** visiting that URL shows your documentation site, not a blank page or a 404.

---

## Part 5 — Your Everyday Workflow Going Forward

This is the loop you'll repeat every time you want to update documentation, add a screenshot, or check in a config file — no step here is a one-time setup.

### Step 11: Edit files in VS Code
1. In GitHub Desktop, menu bar → **Repository → Open in Visual Studio Code** (or open VS Code and use **File → Open Folder** → select your repo folder).
2. Edit any file — for example, open `docs/phase-3-implementation.md` and check off a completed step, or add a screenshot reference.
3. GitHub Copilot will offer autocomplete suggestions as you type (gray "ghost text") — press `Tab` to accept a suggestion, or just keep typing to ignore it.
4. Save the file (`Ctrl+S`).

### Step 12: Commit and push your change
1. Switch to GitHub Desktop — it will already show your edited file under **Changes**.
2. Write a short commit summary describing what you changed, e.g. `Mark Phase 3 pfSense build complete`.
3. Click **Commit to main**.
4. Click **Push origin** (top of the window) to send that commit up to GitHub.com.

### Step 13: Let the pipeline do the rest
1. Every push automatically triggers **Docs CI** (checks your work) and, if that passes, **Docs Deploy** (publishes the updated site).
2. Check the **Actions** tab if you want to watch it happen, or just wait 1-2 minutes and refresh your live docs site — your change will be there.

---

## Quick Troubleshooting

| Problem | Likely cause / fix |
|---|---|
| Red X on "Lint Markdown" | A Markdown formatting issue — click into the failed job to see the exact line/file it's complaining about |
| Red X on "Check Links" | A link in your docs is broken or unreachable — fix or remove it |
| Red X on "Validate Docker Compose Files" | A syntax error in a `docker-compose.yml` — the job log will show the exact YAML error |
| Red X on "Scan for Accidentally Committed Secrets" | You committed a real password/API key somewhere — remove it immediately, rotate that credential, and re-commit |
| Live site not updating after a push | Check the **Actions** tab — if Docs CI failed, Docs Deploy never runs. Fix the CI failure first |
| GitHub Desktop shows no changes after editing | Confirm you saved the file in VS Code (`Ctrl+S`) — unsaved changes don't show up in GitHub Desktop |

---

## Glossary (plain-language)

- **Repository ("repo"):** a project folder that git tracks the history of.
- **Commit:** a saved snapshot of your files at a point in time, with a description.
- **Push:** uploading your local commits to GitHub.com.
- **Pull:** downloading commits from GitHub.com that aren't on your computer yet (matters once you're working from more than one machine).
- **Branch:** a parallel line of work; this project only uses `main` day-to-day, and `gh-pages` automatically for the published site — you won't touch `gh-pages` directly.
- **Workflow / Action:** an automated script that runs on GitHub's servers whenever you push — this is the "CI/CD" part.
- **CI (Continuous Integration):** automatically checking your work every time you push.
- **CD (Continuous Deployment):** automatically publishing your work once it passes CI.
