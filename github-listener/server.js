const express = require('express');
const crypto = require('crypto');
const { exec } = require('child_process');
const urlencodedParser = express.urlencoded({ extended: true });

const app = express();
const PORT = process.env.PORT || 8765;

// Build status tracker
let buildStatus = {
  lastBuild: null,
  lastCommit: null,
  lastCommitMessage: null,
  lastRepo: null,
  lastBranch: null,
  isBuilding: false,
  lastBuildTime: null
};

// GitHub webhook secret (set in environment)
const GITHUB_SECRET = process.env.GITHUB_SECRET || '';

app.use(express.json());

// Verify GitHub webhook signature
function verifySignature(req, res, buf) {
  if (!GITHUB_SECRET) return true;
  
  const signature = req.headers['x-hub-signature-256'];
  if (!signature) return false;
  
  const hmac = crypto.createHmac('sha256', GITHUB_SECRET);
  const digest = 'sha256=' + hmac.update(buf).digest('hex');
  
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(digest));
}

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'GitHub Listener running', events: ['push', 'pull_request', 'release'] });
});

// Build status endpoint
app.get('/status', (req, res) => {
  res.json(buildStatus);
});

// OpenClaw current activity endpoint
app.get('/openclaw', (req, res) => {
  const fs = require('fs');
  const os = require('os');
  
  // Find the most recent session file
  const sessionsDir = os.homedir() + '/.openclaw/agents/garden/sessions';
  let openClawStatus = { isWorking: false, lastUserMessage: null, lastAssistantMessage: null, currentTask: null };
  
  try {
    const files = fs.readdirSync(sessionsDir).filter(f => f.endsWith('.jsonl'));
    if (files.length === 0) {
      return res.json(openClawStatus);
    }
    
    // Sort by modification time, newest first
    const sorted = files.map(f => ({
      name: f,
      mtime: fs.statSync(sessionsDir + '/' + f).mtime
    })).sort((a, b) => b.mtime - a.mtime);
    
    const latestSession = sessionsDir + '/' + sorted[0].name;
    const lines = fs.readFileSync(latestSession, 'utf8').trim().split('\n').filter(l => l.trim());
    
    // Find last user and assistant messages
    let lastUser = null;
    let lastAssistant = null;
    
    for (let i = lines.length - 1; i >= 0; i--) {
      try {
        const msg = JSON.parse(lines[i]);
        if (msg.message?.role === 'user' && !lastUser) {
          const content = msg.message.content;
          lastUser = Array.isArray(content) ? content.find(c => c.type === 'text')?.text?.substring(0, 200) : content?.substring(0, 200);
        }
        if (msg.message?.role === 'assistant' && !lastAssistant) {
          const content = msg.message.content;
          if (Array.isArray(content)) {
            const textPart = content.find(c => c.type === 'text');
            lastAssistant = textPart?.text?.substring(0, 200);
          }
        }
        if (lastUser && lastAssistant) break;
      } catch (e) {}
    }
    
    openClawStatus = {
      isWorking: sorted[0].mtime > new Date(Date.now() - 60000), // active in last minute
      lastUserMessage: lastUser,
      lastAssistantMessage: lastAssistant,
      currentTask: lastAssistant ? lastAssistant.substring(0, 100) : null
    };
  } catch (e) {
    console.log('Error reading OpenClaw session:', e.message);
  }
  
  res.json(openClawStatus);
});

// Kill any previous builds to avoid queued builds
function killPreviousBuilds() {
  console.log('🛑 Killing previous builds...');
  exec('pkill -9 -f flutter; pkill -9 -f xcodebuild; pkill -9 -f "flutter run"; pkill -9 -f "flutter build"', (err) => {
    if (err) {
      console.log('No previous builds to kill (or none found)');
    } else {
      console.log('✅ Previous builds killed');
    }
  });
}

// Pull latest from the triggered repo
function pullRepo(repoName) {
  const repoPaths = {
    'atg_monorepo': '/Users/peanut/.openclaw/workspace/atg_monorepo',
    'keepMovin': '/Users/peanut/.openclaw/workspace/keepMovin',
    'BuyAHabit': '/Users/peanut/.openclaw/workspace/buyahabit',
    'buyahabit': '/Users/peanut/.openclaw/workspace/buyahabit',
    'GardenManager': '/Users/peanut/.openclaw/workspace/GardenManager'
  };
  
  const repoPath = repoPaths[repoName];
  if (repoPath) {
    console.log(`📥 Pulling latest from ${repoName}...`);
    // Use git stash to preserve local changes, then pull, then stash pop
    // If stash fails (no changes), it still pulls
    // If pull conflicts with stash, we discard local changes and re-apply stash
    exec(`cd "${repoPath}" && git stash push -m "auto-stash before build" --include-untracked || true`, (stashErr, stashOut, stashErr2) => {
      exec(`cd "${repoPath}" && git fetch origin && git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)`, (err, stdout, stderr) => {
        if (err) {
          console.log(`⚠️ Failed to fetch/reset ${repoName}:`, err.message);
        } else {
          console.log(`✅ Updated ${repoName}:`, stdout.trim());
        }
        // Try to restore stashed changes (will fail if nothing was stashed, which is fine)
        exec(`cd "${repoPath}" && git stash pop || true`, (popErr, popOut, popErr2) => {
          if (popErr) {
            console.log(`No stash to restore (or clean checkout)`);
          } else {
            console.log(`Restored stashed changes:`, popOut.trim());
          }
        });
      });
    });
  }
}

// Webhook endpoint - handles GitHub webhooks (form-urlencoded)
app.use(express.urlencoded({ extended: true }));
app.post('/webhook', (req, res) => {
  const event = req.headers['x-github-event'];
  
  // Handle form-urlencoded (payload in "payload" field)
  let payload = req.body;
  if (typeof payload.payload === 'string') {
    try {
      payload = JSON.parse(payload.payload);
    } catch (e) {
      console.log('Failed to parse payload:', e.message);
    }
  }
  
  console.log(`Received ${event} event`);
  console.log('Repo:', payload.repository?.name, 'Branch:', payload.ref?.replace('refs/heads/', ''));
  
  // Handle different event types
  switch (event) {
    case 'push':
      handlePush(payload);
      break;
    case 'pull_request':
      handlePullRequest(payload);
      break;
    case 'release':
      handleRelease(payload);
      break;
    default:
      console.log(`Unhandled event: ${event}`);
  }
  
  res.json({ received: true, event });
});

function handlePush(payload) {
  const ref = payload.ref || payload.after;
  const branch = ref ? ref.replace('refs/heads/', '') : 'unknown';
  const commits = payload.commits || [];
  const pusher = payload.pusher || {};
  const repository = payload.repository || {};
  const repoName = repository.name;
  const before = payload.before;
  const after = payload.after;
  
  // Get the most recent commit message
  const commitMessage = commits.length > 0 ? commits[0].message : 'Unknown commit';
  
  console.log(`Push to ${branch} by ${pusher.name} (repo: ${repoName})`);
  console.log(`Commits: ${commits.length}, before: ${before}, after: ${after}`);
  console.log(`Latest commit: ${commitMessage}`);
  
  // Check if this is actually a meaningful push (not just a tag creation or force push)
  if (before === '0000000000000000000000000000000000000000') {
    console.log(`Ignoring initial branch push (no commits yet)`);
    return;
  }
  
  if (commits.length === 0) {
    console.log(`Ignoring empty push (no new commits)`);
    return;
  }
  
  // Kill any previous builds before starting new one
  killPreviousBuilds();
  
  // Update build status
  buildStatus.lastCommit = after;
  buildStatus.lastCommitMessage = commitMessage;
  buildStatus.lastRepo = repoName;
  buildStatus.lastBranch = branch;
  buildStatus.isBuilding = true;
  buildStatus.lastBuildTime = new Date().toISOString();
  
  // Pull latest from the triggered repo
  pullRepo(repoName);
  
  // Route based on repository
  if (repoName === 'atg_monorepo' && branch === 'Peaches') {
    console.log('🔥 Triggering ATG iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/atg_monorepo/run_release_iphone.sh', 'ATG', commitMessage);
  } else if (repoName === 'keepMovin') {
    console.log('📱 Triggering keepMovin iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/keepMovin/run_release_iphone.sh', 'KeepMovin', commitMessage);
  } else if (repoName === 'BuyAHabit' || repoName === 'buyahabit') {
    console.log('💰 Triggering BuyAHabit iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/buyahabit/build_local_or_testflight.sh', 'BuyAHabit', commitMessage);
  } else if (repoName === 'GardenManager') {
    console.log('🌱 Triggering GardenManager iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/GardenManager/run_release_iphone.sh', 'GardenManager', commitMessage);
  } else {
    console.log(`No build configured for repo: ${repoName} branch: ${branch}`);
  }
}

const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 10000;
const AUTO_FIX_AT_ATTEMPT = 2;

// Track auto-fix state to avoid infinite loops
let autoFixAttempted = {}; // { appName: { timestamp } }

function shouldAutoFix(appName) {
  const state = autoFixAttempted[appName];
  if (!state) return true;
  
  // If we attempted a fix in the last 5 minutes, don't auto-fix again
  if (Date.now() - state.timestamp < 5 * 60 * 1000) {
    console.log(`⏭️ Skipping auto-fix for ${appName} - already attempted fix recently`);
    return false;
  }
  return true;
}

function markAutoFixing(appName) {
  autoFixAttempted[appName] = { timestamp: Date.now(), fixing: true };
}

function markAutoFixDone(appName) {
  autoFixAttempted[appName] = { timestamp: Date.now() };
}

function triggerBuild(scriptPath, appName, commitMessage, attempt = 1, previousOutput = '') {
  // Send message that build is starting
  const shortCommitMsg = commitMessage.length > 100 ? commitMessage.substring(0, 100) + '...' : commitMessage;
  
  if (attempt === 1) {
    sendTelegramMessage(`🏗️ ${appName} build started...\n\nCommit: ${shortCommitMsg}`);
  } else {
    sendTelegramMessage(`🔄 ${appName} build attempt ${attempt} of ${MAX_RETRIES + 1}...`);
  }
  
  exec(`bash "${scriptPath}" 2>&1`, { timeout: 600000 }, (error, stdout, stderr) => {
    const fullOutput = stdout + '\n' + stderr;
    const buildSucceeded = fullOutput.includes('BUILD SUCCEEDED') || 
                           fullOutput.includes('BUILD SUCCEEDED') ||
                           fullOutput.includes('App launched successfully') || 
                           fullOutput.includes('Build completed successfully!') || 
                           fullOutput.includes('Build and install completed successfully!') ||
                           fullOutput.includes('ARCHIVE SUCCEEDED') ||
                           fullOutput.includes('UPLOAD SUCCEEDED');
    const buildFailed = error || fullOutput.includes('BUILD FAILED') || fullOutput.includes('ARCHIVE FAILED');
    
    if (buildSucceeded) {
      console.log(`${appName} build output:`, stdout);
      console.log(`✅ ${appName} build triggered successfully (attempt ${attempt})`);
      buildStatus.isBuilding = false;
      buildStatus.lastBuild = 'success';
      if (attempt > 1) {
        sendTelegramMessage(`✅ ${appName} build succeeded on retry ${attempt}!\n\nCommit: ${shortCommitMsg}`);
      } else {
        sendTelegramMessage(`✅ ${appName} build succeeded!\n\nCommit: ${shortCommitMsg}`);
      }
      return;
    }
    
    if (buildFailed) {
      console.error(`${appName} build FAILED (attempt ${attempt}):`, error?.message || 'Build error');
      
      // After 2nd attempt fails, trigger auto-fix then retry
      if (attempt === AUTO_FIX_AT_ATTEMPT && shouldAutoFix(appName)) {
        console.log(`🤖 Attempt ${attempt} failed. Running AI auto-fix...`);
        const errors = fullOutput.split('\n').filter(line => 
          line.includes('error:') || 
          line.includes('Error:') || 
          line.includes('BUILD FAILED') ||
          line.includes('fatal:')
        ).slice(0, 8).join('\n');
        
        sendTelegramMessage(`🤖 Attempt 2 failed for ${appName}. Analyzing and attempting fix...`);
        
        markAutoFixing(appName);
        
        // Run auto-fix - I will fix code then push to GitHub which triggers new build
        autoFixWithAI(appName, scriptPath, fullOutput, shortCommitMsg);
        // Don't auto-retry - wait for GitHub push to trigger new build
        return;
      }
      
      if (attempt <= MAX_RETRIES) {
        console.log(`⏳ Retrying in ${RETRY_DELAY_MS / 1000}s...`);
        setTimeout(() => {
          triggerBuild(scriptPath, appName, commitMessage, attempt + 1, fullOutput);
        }, RETRY_DELAY_MS);
        return;
      }
      
      // All retries exhausted
      const errors = fullOutput.split('\n').filter(line => 
        line.includes('error:') || 
        line.includes('Error:') || 
        line.includes('BUILD FAILED') ||
        line.includes('fatal:')
      ).slice(0, 8).join('\n');
      sendTelegramMessage(`❌ ${appName} build FAILED after ${MAX_RETRIES + 1} attempts!\n\nCommit: ${shortCommitMsg}\n\nError:\n${errors || error?.message || 'Unknown error - check logs'}`);
      
      // Attempt AI auto-fix (for future reference)
      console.log('🤖 All retries exhausted. Notifying about failure.');
      buildStatus.isBuilding = false;
      buildStatus.lastBuild = 'failed';
      return;
    }
    
    // Build completed but unclear if it succeeded or failed
    console.log(`${appName} build output:`, stdout);
    if (stderr) console.error(`${appName} build stderr:`, stderr);
  });
}

// AI Auto-fix function - notifies me via Telegram, I fix then push to GitHub
async function autoFixWithAI(appName, scriptPath, buildOutput, commitMessage) {
  const errors = buildOutput.split('\n').filter(line => 
    line.includes('error:') || 
    line.includes('Error:') || 
    line.includes('BUILD FAILED') ||
    line.includes('fatal:')
  ).slice(0, 15).join('\n');
  const repoPath = scriptPath.replace('/run_release_iphone.sh', '');
  
  console.log(`🤖 Auto-fix for ${appName}...`);
  
  // Write error to a file for me to analyze
  const fixScriptPath = `/tmp/${appName.toLowerCase()}_build_error.json`;
  const fs = require('fs');
  const errorData = {
    appName,
    repoPath,
    scriptPath,
    errors,
    commitMessage,
    fullOutput: buildOutput.substring(0, 50000),
    timestamp: new Date().toISOString()
  };
  fs.writeFileSync(fixScriptPath, JSON.stringify(errorData, null, 2));
  
  // Send me detailed notification
  sendTelegramMessage(`🤖 AUTO-FIX NEEDED for ${appName}\n\nErrors:\n${errors.substring(0, 1000)}\n\nRepo: ${repoPath}\n\nPlease fix and push to GitHub to trigger retry.`);
  
  // Mark that we've attempted fix - when I push and a new build triggers, 
  // shouldAutoFix will return false for 5 min to avoid another auto-fix loop
  markAutoFixDone(appName);
}

function sendTelegramMessage(text) {
  const https = require('https');
  const token = '8799248997:AAGYVuR1NpGkHAIqTiZG1tHxP_3_J4bCP58';
  const chatId = '7145887916';
  
  const postData = JSON.stringify({
    chat_id: chatId,
    text: text
  });
  
  const options = {
    hostname: 'api.telegram.org',
    path: `/bot${token}/sendMessage`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };
  
  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      console.log('Telegram response status:', res.statusCode);
      console.log('Telegram response body:', data.substring(0, 200));
      if (res.statusCode === 200) {
        console.log('Telegram notification sent successfully');
      } else {
        console.error('Telegram notification failed:', res.statusCode, data);
      }
    });
  });
  
  req.on('error', (e) => console.error('Telegram error:', e.message));
  req.write(postData);
  req.end();
}

function handlePullRequest(payload) {
  const { action, pull_request } = payload;
  const { title, head, base } = pull_request || {};
  
  console.log(`PR ${action}: "${title}" (${head?.ref} -> ${base?.ref})`);
  
  // TODO: Add actions here
}

function handleRelease(payload) {
  const { action, release } = payload;
  const { tag_name, name } = release || {};
  
  console.log(`Release ${action}: ${name || tag_name}`);
  
  // TODO: Add actions here
}

// Start server
app.listen(PORT, () => {
  console.log(`GitHub Listener running on port ${PORT}`);
  console.log(`Webhook URL: /webhook`);
});
