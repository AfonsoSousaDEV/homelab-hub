# 📬 Email Digest: setup guide

Every morning at 08:00 this reads your unread emails, uses the local AI (Ollama) to pick out what's important, and posts a short summary to Discord.

It only **reads** your email. It never sends, deletes or marks anything as read.

⏱️ About 20 minutes, once.

---

## Before you start
- [ ] **Docker Desktop** is open and says *Engine running*
- [ ] **Ollama** is installed, and you've downloaded the model: `ollama pull qwen3:4b`
- [ ] You've pulled the latest code from this repo
- [ ] You can edit a channel in our Discord server

All commands below are run in your **Ubuntu (WSL) terminal**, inside the repo folder.

---

## Step 1: Create a Discord webhook (1 min)
1. In Discord, hover over the channel where the digest should go → click ⚙️ **Edit Channel**.
2. **Integrations** → **Webhooks** → **New Webhook**.
3. Click **Copy Webhook URL**. You'll paste it in the next step.

## Step 2: Run the setup script (2 min)
```bash
bash scripts/setup.sh
```
Paste the Discord URL when it asks. When it finishes you should see:
```
✔ n8n is running at http://localhost:5678
✔ Imported workflow 'Email digest → Discord'
✔ Ollama is reachable and 'qwen3:4b' is ready
```
If you see ⚠ or ❌, follow what it says, or check **If something goes wrong** at the bottom. The script is safe to run again.

## Step 3: Create your n8n account (1 min)
Open **http://localhost:5678** and fill in the sign-up form. This account only exists on your PC.

## Step 4: Connect Gmail (10 min)
Google needs a "key" before n8n can read your email. You create it once in Google Cloud. It's free, and you can ignore any billing prompts.

**In Google Cloud:**
1. Go to https://console.cloud.google.com. Top-left project menu → **New project** → name it `email-digest` → **Create**. Make sure it's selected.
2. Open https://console.cloud.google.com/apis/library/gmail.googleapis.com → click **Enable**.
3. Open https://console.cloud.google.com/auth/overview → **Get started**:
   - App name: `Email Digest`, support email: yours → **Next**
   - Audience: **External** → **Next**
   - Contact email: yours → **Next** → tick the agreement → **Create**
4. Left menu **Audience** → under *Test users* click **Add users** → type your Gmail address → **Save**.
5. Left menu **Clients** → **Create client**:
   - Application type: **Web application**
   - Under *Authorized redirect URIs* click **Add URI** and paste:
     `http://localhost:5678/rest/oauth2-credential/callback`
   - Click **Create**.
6. **Copy the Client ID and Client secret right away** and paste them somewhere temporary, because the secret may only be shown once.

**In n8n:**

7. Open the workflow **Email digest → Discord**.
8. Double-click the **Get unread emails** box → under *Credential to connect with* → **Create new credential**.
9. Paste the **Client ID** and **Client secret** → click **Sign in with Google**.
10. Choose your Gmail account. Google will say *"Google hasn't verified this app"*. That's normal, because it's your own app: click **Continue**, then allow access.
11. n8n should now show **Account connected**. Close the box.

## Step 5: Test it and switch it on (2 min)
1. Click **Execute workflow** at the bottom of the screen. Each box turns green as it runs. *Ask Ollama* can take 1–2 minutes.
2. Check Discord: the digest should be there. 🎉
   (If you have no unread emails from the last 24h, nothing is posted. Mark a recent email as unread and try again.)
3. Turn it on with the **Active** toggle (called **Publish** in newer n8n versions) at the top right. From now on it runs every day at 08:00 while Docker Desktop is open.

---

## If something goes wrong
| Problem | Fix |
|---|---|
| ❌ *Docker isn't running* | Open Docker Desktop, wait for *Engine running*, run the script again. |
| ⚠ *n8n can't reach Ollama* | Run `ollama list` to check Ollama is running. If Ollama runs inside Ubuntu/WSL, make it reachable from Docker: run `sudo systemctl edit ollama`, add the two lines below, save, then run `sudo systemctl restart ollama` and the setup script again. |
| ⚠ *model isn't downloaded* | `ollama pull qwen3:4b` |
| Google says *Access blocked* or *403* | You skipped step 4.4: add your Gmail as a **Test user**. |
| Google says *redirect_uri_mismatch* | The redirect URI in step 4.5 must be exactly `http://localhost:5678/rest/oauth2-credential/callback`. |
| *Ask Ollama* times out | Your PC is slow with many emails. Open **Get unread emails** and lower *Limit* from 25 to 10. |
| Discord shows *Could not read the AI answer* | The AI gave a bad answer. Just run it again. |
| *Post to Discord* is red | The webhook URL is wrong. Fix `DISCORD_WEBHOOK_URL` in the `.env` file, then run `docker compose up -d`. |

Lines to add for Ollama in WSL (from the Ollama row above):
```
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
```

Still stuck? Send a screenshot of the red box (click it to see the error) to the team chat.

---

## Extras (not needed to get it working)
**Change things.** Open a box in n8n and edit it:
- *Every day at 08:00*: the time (cron `0 8 * * *`)
- *Get unread emails*: which emails are read (Gmail search, default `is:unread newer_than:1d`)
- *Prepare emails*: what the AI considers important (`systemPrompt`)

**Share your workflow changes with the team.** Run `bash scripts/export-workflows.sh`, then commit and open a PR.
**Get a teammate's changes.** Pull, then run `bash scripts/import-workflows.sh`, then redo step 4.8–4.11. Importing resets the Gmail connection, but you can pick your existing credential from the dropdown.

**Stop or start n8n:** `docker compose stop` / `docker compose start`
