#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const defaultProjectRef = process.env.SUPABASE_PROJECT_REF ?? 'eecfrzvutrhftwvyebpq';
const managementToken =
    process.env.SUPABASE_MANAGEMENT_TOKEN ??
    process.env.SUPABASE_ACCESS_TOKEN ??
    '';
const apiBaseUrl = process.env.SUPABASE_MANAGEMENT_API_BASE ?? 'https://api.supabase.com/v1';

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const readOnly = args.includes('--read-only');
const withSequenceReset = args.includes('--with-sequence-reset');

const sqlArgs = args.filter((arg) => !arg.startsWith('--'));
const defaultSqlFiles = [
    resolve(repoRoot, 'api/supabase/schema.sql'),
];

if (withSequenceReset) {
    defaultSqlFiles.push(
        resolve(repoRoot, 'api/supabase/reset_content_identity_sequences.sql'),
    );
}

const sqlFiles = (sqlArgs.length > 0 ? sqlArgs : defaultSqlFiles).map((filePath) =>
    resolve(process.cwd(), filePath),
);

function printUsageAndExit(message) {
    if (message) {
        console.error(message);
        console.error('');
    }

    console.error(
        [
            'Usage: node api/supabase/apply_management_sql.mjs [--dry-run] [--read-only] [--with-sequence-reset] [sql-file ...]',
            '',
            'Environment:',
            '  SUPABASE_MANAGEMENT_TOKEN or SUPABASE_ACCESS_TOKEN  Supabase PAT required by the Management API',
            '  SUPABASE_PROJECT_REF                              Defaults to eecfrzvutrhftwvyebpq',
            '',
            'Defaults to applying api/supabase/schema.sql.',
        ].join('\n'),
    );

    process.exit(1);
}

async function executeSqlFile(filePath) {
    const query = readFileSync(filePath, 'utf8');
    const response = await fetch(`${apiBaseUrl}/projects/${defaultProjectRef}/database/query`, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${managementToken}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            query,
            read_only: readOnly,
        }),
    });

    const responseText = await response.text();
    if (!response.ok) {
        throw new Error(
            [
                `Management API query failed for ${filePath}`,
                `status=${response.status}`,
                responseText.slice(0, 2000),
            ].join('\n'),
        );
    }

    console.log(`Applied ${basename(filePath)} (${response.status})`);
    if (responseText.trim().length > 0) {
        console.log(responseText.slice(0, 1000));
    }
}

async function main() {
    if (!managementToken) {
        printUsageAndExit('Missing SUPABASE_MANAGEMENT_TOKEN / SUPABASE_ACCESS_TOKEN.');
    }

    if (sqlFiles.length === 0) {
        printUsageAndExit('No SQL files selected.');
    }

    console.log(`Project ref: ${defaultProjectRef}`);
    console.log(`Read only: ${readOnly}`);
    console.log('SQL files:');
    for (const filePath of sqlFiles) {
        console.log(`- ${filePath}`);
    }

    if (dryRun) {
        return;
    }

    for (const filePath of sqlFiles) {
        await executeSqlFile(filePath);
    }
}

main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
});