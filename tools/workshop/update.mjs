// Sets what SteamCMD can't on the Workshop item: the addon type and tags, the title and the
// description (with æ, ø and å). Also finds the item when its ID isn't known yet.
//   node update.mjs find     → prints the ID of the newest item called the same as the title (or nothing)
//   node update.mjs <id>     → sets the type, tags, title and description on that item
// Needs STEAM_REFRESH_TOKEN (see login.mjs).
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { login, userFiles, details, update } from './steam.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const cfg = JSON.parse(fs.readFileSync(path.join(HERE, 'workshop.json'), 'utf8'));
const arg = process.argv[2];
const token = process.env.STEAM_REFRESH_TOKEN;
if (!token) { console.error('STEAM_REFRESH_TOKEN is not set'); process.exit(1); }

const client = await login(token);
const log = (...a) => console.error(...a);
try {
  if (arg === 'find') {
    const files = await userFiles(client, cfg.appid);
    log(`Your ${files.length} Garry's Mod Workshop items:`);
    for (const f of files) log(`  ${f.publishedfileid}  ${f.title}  [${(f.tags || []).map(t => t.tag).join(', ')}]`);
    const mine = files.filter(f => f.title === cfg.title).sort((a, b) => b.time_created - a.time_created);
    if (mine.length > 1) log(`::warning::There are ${mine.length} items called "${cfg.title}" – using the newest, ${mine[0].publishedfileid}. Delete the others on Steam.`);
    if (mine.length) process.stdout.write(String(mine[0].publishedfileid));
  } else {
    const id = arg;
    const description = fs.readFileSync(path.join(HERE, cfg.description), 'utf8');
    await update(client, { appid: cfg.appid, publishedfileid: id, title: cfg.title, file_description: description, tags: cfg.tags });
    const d = await details(client, id);
    log(`Updated ${id}: "${d.title}", tags [${(d.tags || []).map(t => t.tag).join(', ')}], description ${(d.file_description || '').length} characters`);
  }
} finally {
  client.logOff();
  setTimeout(() => process.exit(process.exitCode || 0), 500);
}
