#!/usr/bin/env node

// Answers "is the build I just uploaded actually installable?" without opening
// App Store Connect. Apple accepts an upload immediately but processes it for
// ~5-30 minutes; only processingState VALID means testers can install it.
//
// Credentials come from .testflight.env (gitignored) or the environment:
//   APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID,
//   APP_STORE_CONNECT_KEY_PATH (absolute path to the .p8)

import { createSign } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const BUNDLE_ID = 'Crocobyte.TrailRider'
const API = 'https://api.appstoreconnect.apple.com'

const projectDirectory = dirname(dirname(fileURLToPath(import.meta.url)))

function loadCredentials() {
  const credentials = { ...process.env }

  try {
    const file = readFileSync(join(projectDirectory, '.testflight.env'), 'utf8')
    for (const line of file.split('\n')) {
      const match = line.match(/^\s*(?:export\s+)?([A-Z_]+)\s*=\s*(.*)$/)
      if (!match) continue
      // Environment variables win, so a one-off override needs no file edit.
      if (process.env[match[1]]) continue
      credentials[match[1]] = match[2].trim().replace(/^["']|["']$/g, '')
    }
  } catch (error) {
    if (error.code !== 'ENOENT') throw error
  }

  const missing = [
    'APP_STORE_CONNECT_KEY_ID',
    'APP_STORE_CONNECT_ISSUER_ID',
    'APP_STORE_CONNECT_KEY_PATH',
  ].filter((name) => !credentials[name])

  if (missing.length > 0) {
    console.error(`Missing credentials: ${missing.join(', ')}`)
    console.error('Set them in .testflight.env or the environment.')
    process.exit(1)
  }

  return credentials
}

const base64url = (input) => Buffer.from(input).toString('base64url')

function mintToken({ keyId, issuerId, privateKey }) {
  const issuedAt = Math.floor(Date.now() / 1000)
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' }
  // Apple rejects tokens with a lifetime over 20 minutes.
  const payload = {
    iss: issuerId,
    iat: issuedAt,
    exp: issuedAt + 15 * 60,
    aud: 'appstoreconnect-v1',
  }

  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`

  // JOSE wants the raw r||s pair; without ieee-p1363 Node emits DER and Apple
  // answers 401 on a signature that is otherwise perfectly valid.
  const signature = createSign('SHA256')
    .update(signingInput)
    .sign({ key: privateKey, dsaEncoding: 'ieee-p1363' })

  return `${signingInput}.${signature.toString('base64url')}`
}

async function get(path, token) {
  const response = await fetch(`${API}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  })

  if (!response.ok) {
    const body = await response.text()
    throw new Error(`${response.status} ${response.statusText} for ${path}\n${body}`)
  }

  return response.json()
}

const credentials = loadCredentials()
const token = mintToken({
  keyId: credentials.APP_STORE_CONNECT_KEY_ID,
  issuerId: credentials.APP_STORE_CONNECT_ISSUER_ID,
  privateKey: readFileSync(credentials.APP_STORE_CONNECT_KEY_PATH, 'utf8'),
})

const apps = await get(`/v1/apps?filter[bundleId]=${BUNDLE_ID}`, token)
const app = apps.data?.[0]

if (!app) {
  console.error(`No App Store Connect app record found for ${BUNDLE_ID}.`)

  // A missing record and a typo'd bundle ID produce the same empty result, so
  // show what the team actually has before sending anyone to the web console.
  const existing = await get('/v1/apps?limit=50', token)
  if (existing.data.length > 0) {
    console.error('\nApps that do exist in this team:')
    for (const other of existing.data) {
      console.error(`  ${other.attributes.bundleId}  —  ${other.attributes.name}`)
    }
  }

  console.error('\nCreate it at https://appstoreconnect.apple.com before uploading.')
  process.exit(1)
}

const builds = await get(
  `/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=5`,
  token,
)

if (builds.data.length === 0) {
  console.log(`No builds uploaded yet for ${BUNDLE_ID}.`)
  process.exit(0)
}

console.log(`${app.attributes.name} (${BUNDLE_ID})\n`)

for (const build of builds.data) {
  const { version, processingState, uploadedDate, expired } = build.attributes
  const status =
    processingState === 'VALID'
      ? expired
        ? 'expired'
        : 'installable'
      : processingState.toLowerCase()

  console.log(`  build ${version.padEnd(6)} ${uploadedDate}  ${processingState} — ${status}`)
}

const latest = builds.data[0].attributes
if (latest.processingState === 'PROCESSING') {
  console.log('\nLatest build is still processing; re-run in a few minutes.')
} else if (latest.processingState === 'FAILED' || latest.processingState === 'INVALID') {
  console.log('\nLatest build failed processing. App Store Connect emails the reason.')
}
