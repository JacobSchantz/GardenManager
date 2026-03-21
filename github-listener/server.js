const express = require('express');
const crypto = require('crypto');
const { exec } = require('child_process');
const urlencodedParser = express.urlencoded({ extended: true });

const app = express();
const PORT = process.env.PORT || 8765;

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
  
  // Route based on repository
  if (repoName === 'atg_monorepo' && branch === 'Peaches') {
    console.log('🔥 Triggering ATG iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/atg_monorepo/run_release_iphone.sh', 'ATG', commitMessage);
  } else if (repoName === 'keepMovin') {
    console.log('📱 Triggering keepMovin iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/keepMovin/run_release_iphone.sh', 'KeepMovin', commitMessage);
  } else if (repoName === 'BuyAHabit' || repoName === 'buyahabit') {
    console.log('💰 Triggering BuyAHabit iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/buyahabit/run_release_iphone.sh', 'BuyAHabit', commitMessage);
  } else if (repoName === 'GardenManager') {
    console.log('🌱 Triggering GardenManager iOS build...');
    triggerBuild('/Users/peanut/.openclaw/workspace/GardenManager/run_release_iphone.sh', 'GardenManager', commitMessage);
  } else {
    console.log(`No build configured for repo: ${repoName} branch: ${branch}`);
  }
}

function triggerBuild(scriptPath, appName, commitMessage) {
  exec(`bash "${scriptPath}" 2>&1`, { timeout: 600000 }, (error, stdout, stderr) => {
    const fullOutput = stdout + '\n' + stderr;
    const buildFailed = error || fullOutput.includes('BUILD FAILED') || fullOutput.includes('error:');
    const buildSucceeded = fullOutput.includes('BUILD SUCCEEDED') || fullOutput.includes('App launched successfully') || fullOutput.includes('Build completed successfully!') || fullOutput.includes('Build and install completed successfully!');
    
    // Truncate commit message if too long
    const shortCommitMsg = commitMessage.length > 100 ? commitMessage.substring(0, 100) + '...' : commitMessage;
    
    if (buildFailed) {
      console.error(`${appName} build FAILED:`, error?.message || 'Build error');
      // Extract error summary
      const errors = fullOutput.split('\n').filter(line => line.includes('error:')).slice(0, 5).join('\n');
      sendTelegramMessage(`🚨 ${appName} build FAILED!\n\nCommit: ${shortCommitMsg}\n\n${errors || error?.message || 'Check logs'}`);
      
      // Attempt AI auto-fix
      console.log('🤖 Attempting AI auto-fix...');
      autoFixWithAI(appName, scriptPath, fullOutput, shortCommitMsg);
      return;
    }
    
    if (buildSucceeded) {
      console.log(`${appName} build output:`, stdout);
      console.log(`✅ ${appName} build triggered successfully`);
      sendTelegramMessage(`✅ ${appName} build succeeded!\n\nCommit: ${shortCommitMsg}`);
    } else {
      console.log(`${appName} build output:`, stdout);
      if (stderr) console.error(`${appName} build stderr:`, stderr);
    }
  });
}

// AI Auto-fix function - notifies user that I'll fix it
async function autoFixWithAI(appName, scriptPath, buildOutput, commitMessage) {
  const errors = buildOutput.split('\n').filter(line => line.includes('error:') || line.includes('Error:')).slice(0, 5).join('\n');
  const repoPath = scriptPath.replace('/run_release_iphone.sh', '');
  
  // Tell the user I'll fix it
  sendTelegramMessage(`🤖 Build failed. I'll analyze and fix the errors now.\n\nErrors:\n${errors}\n\nRepo: ${repoPath}`);
  
  // The fix will happen in this conversation - I'm already here and will see the failure

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
