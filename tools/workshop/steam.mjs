// Talking to Steam as the Steam client does (steam-user), for the Workshop calls SteamCMD doesn't have.
import SteamUser from 'steam-user';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const Schema = require('steam-user/protobufs/generated/_load.js');
const EMsg = require('steam-user/enums/EMsg.js');

export function login(refreshToken) {
  return new Promise((resolve, reject) => {
    const client = new SteamUser({ autoRelogin: false, renewRefreshTokens: false });
    const t = setTimeout(() => reject(new Error('Steam login timed out')), 60000);
    client.once('loggedOn', () => { clearTimeout(t); resolve(client); });
    client.once('error', e => { clearTimeout(t); reject(e); });
    client.logOn({ refreshToken });
  });
}

// a "service method" call, e.g. PublishedFile.Update#1
export function call(client, method, reqType, resType, data) {
  return new Promise((resolve, reject) => {
    const body = SteamUser._encodeProto(Schema[reqType], data);
    const t = setTimeout(() => reject(new Error(method + ' timed out')), 30000);
    client._send({ msg: EMsg.ServiceMethodCallFromClient, proto: { target_job_name: method } }, body, (res, hdr) => {
      clearTimeout(t);
      const eresult = hdr?.proto?.eresult ?? 1;
      if (eresult !== 1) return reject(new Error(`${method} failed: EResult ${eresult} ${hdr?.proto?.error_message || ''}`));
      resolve(SteamUser._decodeProto(Schema[resType], res));
    });
  });
}

export async function userFiles(client, appid) {
  const r = await call(client, 'PublishedFile.GetUserFiles#1', 'CPublishedFile_GetUserFiles_Request', 'CPublishedFile_GetUserFiles_Response', {
    steamid: client.steamID.getSteamID64(), appid, numperpage: 100, type: 'myfiles', return_tags: true, return_short_description: true,
  });
  return r.publishedfiledetails || [];
}

export async function details(client, id) {
  const r = await call(client, 'PublishedFile.GetDetails#1', 'CPublishedFile_GetDetails_Request', 'CPublishedFile_GetDetails_Response', {
    publishedfileids: [id], includetags: true, includeadditionalpreviews: false, short_description: false,
  });
  return (r.publishedfiledetails || [])[0];
}

export async function update(client, fields) {
  await call(client, 'PublishedFile.Update#1', 'CPublishedFile_Update_Request', 'CPublishedFile_Update_Response', fields);
}
