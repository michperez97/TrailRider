#!/usr/bin/env node

// Answers "is the build I just uploaded actually available to an internal
// tester?" without opening App Store Connect. Apple accepts an upload
// immediately, but processingState VALID is only the first gate: the build must
// also belong to an internal group that contains at least one tester.
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

async function request(path, token, options = {}) {
  const response = await fetch(`${API}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    },
  })

  if (!response.ok) {
    const body = await response.text()
    throw new Error(`${response.status} ${response.statusText} for ${path}\n${body}`)
  }

  if (response.status === 204) return undefined
  return response.json()
}

const get = (path, token) => request(path, token)
const post = (path, token, body) =>
  request(path, token, { method: 'POST', body: JSON.stringify(body) })

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

let betaGroups = await get(
  `/v1/apps/${app.id}/betaGroups?fields[betaGroups]=name,isInternalGroup,hasAccessToAllBuilds&limit=200`,
  token,
)

let internalGroups = betaGroups.data.filter((group) => group.attributes.isInternalGroup)

if (process.argv.includes('--configure-internal-testing')) {
  const emailArgument = process.argv.find((argument) => argument.startsWith('--tester-email='))
  const requestedEmail = emailArgument?.slice('--tester-email='.length).toLowerCase()
  const eligibleRoles = new Set([
    'ACCOUNT_HOLDER',
    'ADMIN',
    'APP_MANAGER',
    'DEVELOPER',
    'MARKETING',
  ])
  const users = await get(
    '/v1/users?fields[users]=username,firstName,lastName,roles,allAppsVisible&include=visibleApps&limit=200&limit[visibleApps]=50',
    token,
  )
  const eligibleUsers = users.data.filter((user) => {
    const canTest = user.attributes.roles.some((role) => eligibleRoles.has(role))
    const canSeeApp =
      user.attributes.allAppsVisible ||
      user.relationships?.visibleApps?.data?.some(({ id }) => id === app.id)
    return canTest && canSeeApp
  })
  const matchingUsers = requestedEmail
    ? eligibleUsers.filter(
        (user) => user.attributes.username.toLowerCase() === requestedEmail,
      )
    : eligibleUsers.filter((user) => user.attributes.roles.includes('ACCOUNT_HOLDER'))

  if (matchingUsers.length !== 1) {
    console.error('Could not choose exactly one internal tester.')
    console.error('Re-run with --tester-email=<App Store Connect username>.')
    console.error('\nEligible users:')
    for (const user of eligibleUsers) {
      console.error(`  ${user.attributes.firstName} ${user.attributes.lastName} <${user.attributes.username}>`)
    }
    process.exit(1)
  }

  const selectedUser = matchingUsers[0]
  let internalGroup = internalGroups[0]

  if (!internalGroup) {
    const created = await post('/v1/betaGroups', token, {
      data: {
        type: 'betaGroups',
        attributes: {
          name: 'Internal Testers',
          isInternalGroup: true,
          hasAccessToAllBuilds: true,
          feedbackEnabled: true,
        },
        relationships: {
          app: { data: { type: 'apps', id: app.id } },
        },
      },
    })
    internalGroup = created.data
    console.log(`Created automatic internal group: ${internalGroup.attributes.name}`)
  }

  let groupTesters = await get(
    `/v1/betaGroups/${internalGroup.id}/betaTesters?fields[betaTesters]=firstName,lastName,email&limit=200`,
    token,
  )
  let assignedTester = groupTesters.data.find(
    (tester) => tester.attributes.email.toLowerCase() === selectedUser.attributes.username.toLowerCase(),
  )

  if (!assignedTester) {
    try {
      await post('/v1/betaTesters', token, {
        data: {
          type: 'betaTesters',
          attributes: {
            email: selectedUser.attributes.username,
            firstName: selectedUser.attributes.firstName,
            lastName: selectedUser.attributes.lastName,
          },
          relationships: {
            betaGroups: {
              data: [{ type: 'betaGroups', id: internalGroup.id }],
            },
          },
        },
      })
    } catch (error) {
      // Apple may return 409 when an existing betaTester record is enrolled.
      // Treat it as success only if the relationship appeared anyway.
      if (!error.message.startsWith('409 ')) throw error
    }

    groupTesters = await get(
      `/v1/betaGroups/${internalGroup.id}/betaTesters?fields[betaTesters]=firstName,lastName,email&limit=200`,
      token,
    )
    assignedTester = groupTesters.data.find(
      (tester) => tester.attributes.email.toLowerCase() === selectedUser.attributes.username.toLowerCase(),
    )
    if (!assignedTester) {
      throw new Error('Apple did not add the selected user to the internal testing group.')
    }
  }
  console.log(`Internal tester ready: ${selectedUser.attributes.firstName} ${selectedUser.attributes.lastName}`)

  betaGroups = await get(
    `/v1/apps/${app.id}/betaGroups?fields[betaGroups]=name,isInternalGroup,hasAccessToAllBuilds&limit=200`,
    token,
  )
  internalGroups = betaGroups.data.filter((group) => group.attributes.isInternalGroup)
}

const groupAccess = await Promise.all(
  internalGroups.map(async (group) => {
    const [groupBuilds, groupTesters] = await Promise.all([
      get(`/v1/betaGroups/${group.id}/relationships/builds?limit=200`, token),
      get(
        `/v1/betaGroups/${group.id}/betaTesters?fields[betaTesters]=firstName,lastName,email,inviteType,state&limit=200`,
        token,
      ),
    ])

    return {
      group,
      buildIds: new Set(groupBuilds.data.map(({ id }) => id)),
      testerCount: groupTesters.data.length,
      testers: groupTesters.data,
    }
  }),
)

if (process.argv.includes('--resend-internal-invitations')) {
  const pendingTesters = groupAccess.flatMap(({ testers }) =>
    testers.filter(({ attributes }) =>
      ['NOT_INVITED', 'INVITED'].includes(attributes.state),
    ),
  )

  if (pendingTesters.length === 0) {
    console.log('No pending internal tester invitations to resend.')
  } else {
    for (const tester of pendingTesters) {
      await post('/v1/betaTesterInvitations', token, {
        data: {
          type: 'betaTesterInvitations',
          relationships: {
            app: { data: { type: 'apps', id: app.id } },
            betaTester: { data: { type: 'betaTesters', id: tester.id } },
          },
        },
      })
      console.log(
        `Resent TestFlight invitation to ${tester.attributes.firstName} ${tester.attributes.lastName}`,
      )
    }
  }
}

console.log(`${app.attributes.name} (${BUNDLE_ID})\n`)

for (const build of builds.data) {
  const { version, processingState, uploadedDate, expired } = build.attributes
  const accessibleGroups = groupAccess.filter(
    ({ group, buildIds }) =>
      group.attributes.hasAccessToAllBuilds || buildIds.has(build.id),
  )
  const testerCount = accessibleGroups.reduce(
    (total, { testerCount: count }) => total + count,
    0,
  )
  const accessibleTesters = accessibleGroups.flatMap(({ testers }) => testers)
  const acceptedTesterCount = accessibleTesters.filter(({ attributes }) =>
    ['ACCEPTED', 'INSTALLED'].includes(attributes.state),
  ).length
  const invitedTesterCount = accessibleTesters.filter(
    ({ attributes }) => attributes.state === 'INVITED',
  ).length

  let status = processingState.toLowerCase()
  if (processingState === 'VALID') {
    if (expired) status = 'expired'
    else if (accessibleGroups.length === 0) status = 'not assigned to an internal group'
    else if (testerCount === 0) status = 'internal group has no testers'
    else if (acceptedTesterCount > 0) {
      status = `available to ${acceptedTesterCount} accepted internal tester${acceptedTesterCount === 1 ? '' : 's'}`
    } else if (invitedTesterCount > 0) {
      status = `invitation pending for ${invitedTesterCount} internal tester${invitedTesterCount === 1 ? '' : 's'}`
    } else {
      status = 'internal tester is not ready'
    }
  }

  console.log(`  build ${version.padEnd(6)} ${uploadedDate}  ${processingState} — ${status}`)
}

if (internalGroups.length === 0) {
  console.log('\nNo internal testing group exists for this app.')
  console.log('App Store Connect → TrailRider_ios → TestFlight → Internal Testing → +')
} else {
  console.log('\nInternal testing groups:')
  for (const { group, testerCount, testers } of groupAccess) {
    const automatic = group.attributes.hasAccessToAllBuilds ? ', automatic builds' : ''
    console.log(`  ${group.attributes.name}: ${testerCount} tester${testerCount === 1 ? '' : 's'}${automatic}`)
    for (const tester of testers) {
      const { firstName, lastName, state } = tester.attributes
      console.log(`    ${firstName} ${lastName}: ${state ?? 'no invitation state'}`)
    }
  }
}

const latest = builds.data[0].attributes
if (latest.processingState === 'PROCESSING') {
  console.log('\nLatest build is still processing; re-run in a few minutes.')
} else if (latest.processingState === 'FAILED' || latest.processingState === 'INVALID') {
  console.log('\nLatest build failed processing. App Store Connect emails the reason.')
}
