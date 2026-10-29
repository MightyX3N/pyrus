// Run this once on your own computer to let GitHub update the Workshop item's type, tags and
// description:   cd tools/workshop  →  npm install  →  node login.mjs
// Scan the QR code with the Steam app on your phone (or log in with your password and Steam Guard
// code), and it prints a login token. Put that token in the repository's secrets as STEAM_REFRESH_TOKEN.
// The token is like a password for your Steam account: don't share it anywhere else.
import { LoginSession, EAuthTokenPlatformType } from 'steam-session';
import qrcode from 'qrcode-terminal';
import readline from 'readline/promises';

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const session = new LoginSession(EAuthTokenPlatformType.SteamClient);
session.on('authenticated', () => {
  console.log('\nLogged in as ' + session.accountName + '.\n');
  console.log('Your token (copy all of it into the secret STEAM_REFRESH_TOKEN):\n');
  console.log(session.refreshToken + '\n');
  rl.close();
  process.exit(0);
});
session.on('timeout', () => { console.log('Took too long – run it again.'); process.exit(1); });
session.on('error', e => { console.log('Error: ' + e.message); process.exit(1); });

const how = (await rl.question('Log in with [Q]R code (Steam app) or [P]assword? ')).trim().toLowerCase();
if (how.startsWith('p')) {
  const accountName = (await rl.question('Steam login name: ')).trim();
  const password = (await rl.question('Password: ')).trim();
  const r = await session.startWithCredentials({ accountName, password });
  if (r.actionRequired) {
    const code = (await rl.question('Steam Guard code (or approve it in the Steam app and just press Enter): ')).trim();
    if (code) await session.submitSteamGuardCode(code);
  }
} else {
  const r = await session.startWithQR();
  qrcode.generate(r.qrChallengeUrl, { small: true });
  console.log('Scan this with the Steam app on your phone (Steam Guard → the QR scanner), then approve it.');
}
