#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const sqlitePath = process.env.SQLITE_DB_PATH ??
    resolve(repoRoot, 'assets/database/breeze_jp.sqlite');
const supabaseUrl = process.env.SUPABASE_URL ??
    'https://eecfrzvutrhftwvyebpq.supabase.co';
const serviceKey = process.env.SUPABASE_SERVICE_KEY ?? '';
const chunkSize = Number.parseInt(process.env.MIGRATION_CHUNK_SIZE ?? '500', 10);
const dryRun = process.argv.includes('--dry-run');
const requiredTables = [
    'grammars',
    'grammar_meanings',
    'grammar_contexts',
    'grammar_examples',
];

function readSqliteRows(sql) {
    const output = execFileSync(
        'sqlite3',
        ['-json', sqlitePath, sql],
        {
            encoding: 'utf8',
            maxBuffer: 64 * 1024 * 1024,
        },
    ).trim();
    return output.length > 0 ? JSON.parse(output) : [];
}

function normalizeTimestamp(value) {
    if (value == null || value === '') {
        return null;
    }
    if (typeof value === 'number') {
        return new Date(value * 1000).toISOString();
    }
    const parsed = new Date(String(value));
    if (Number.isNaN(parsed.getTime())) {
        throw new Error(`Invalid timestamp value: ${value}`);
    }
    return parsed.toISOString();
}

function chunkRows(rows, size) {
    const result = [];
    for (let index = 0; index < rows.length; index += size) {
        result.push(rows.slice(index, index + size));
    }
    return result;
}

async function supabaseRequest(path, { method = 'GET', body, prefer } = {}) {
    const response = await fetch(`${supabaseUrl}/rest/v1${path}`, {
        method,
        headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            'Content-Type': 'application/json',
            ...(prefer ? { Prefer: prefer } : {}),
        },
        body: body == null ? undefined : JSON.stringify(body),
    });

    if (!response.ok) {
        const text = await response.text();
        throw new Error(`${method} ${path} failed: ${response.status} ${text}`);
    }

    return response;
}

async function deleteAll(table) {
    await supabaseRequest(`/${table}?id=gte.0`, {
        method: 'DELETE',
        prefer: 'return=minimal',
    });
}

async function ensureRemoteSchemaReady() {
    const missingTables = [];

    for (const table of requiredTables) {
        const response = await fetch(`${supabaseUrl}/rest/v1/${table}?select=id&limit=1`, {
            method: 'GET',
            headers: {
                apikey: serviceKey,
                Authorization: `Bearer ${serviceKey}`,
            },
        });

        if (response.status === 404) {
            missingTables.push(table);
            continue;
        }

        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Schema check failed for ${table}: ${response.status} ${text}`);
        }
    }

    if (missingTables.length > 0) {
        throw new Error(
            [
                'Remote Supabase schema is not ready for grammar content migration.',
                `Missing tables: ${missingTables.join(', ')}`,
                'Apply api/supabase/schema.sql to the remote database first,',
                'or run api/supabase/apply_management_sql.mjs with a Supabase PAT, then rerun this script.',
            ].join(' '),
        );
    }
}

async function insertAll(table, rows) {
    if (rows.length === 0) {
        return;
    }

    for (const batch of chunkRows(rows, chunkSize)) {
        await supabaseRequest(`/${table}`, {
            method: 'POST',
            body: batch,
            prefer: 'return=minimal',
        });
    }
}

function loadSourceData() {
    return {
        grammars: readSqliteRows('SELECT * FROM grammars ORDER BY id ASC').map((row) => ({
            id: row.id,
            title: row.title,
            jlpt_level: row.jlpt_level,
            usage_frequency: row.usage_frequency ?? 0,
            created_at: normalizeTimestamp(row.created_at),
            updated_at: normalizeTimestamp(row.updated_at),
        })),
        grammar_meanings: readSqliteRows('SELECT * FROM grammar_meanings ORDER BY id ASC').map((row) => ({
            id: row.id,
            grammar_id: row.grammar_id,
            sort_order: row.sort_order ?? 1,
            definition_cn: row.definition_cn,
            definition_en: row.definition_en,
            how_to_use_cn: row.how_to_use_cn,
            how_to_use_en: row.how_to_use_en,
        })),
        grammar_contexts: readSqliteRows('SELECT * FROM grammar_contexts ORDER BY id ASC').map((row) => ({
            id: row.id,
            grammar_id: row.grammar_id,
            when_to_use_cn: row.when_to_use_cn,
            when_to_use_en: row.when_to_use_en,
        })),
        grammar_examples: readSqliteRows('SELECT * FROM grammar_examples ORDER BY id ASC').map((row) => ({
            id: row.id,
            grammar_id: row.grammar_id,
            sort_order: row.sort_order ?? 1,
            sentence: row.sentence,
            translation_cn: row.translation_cn,
            translation_en: row.translation_en,
            audio_url: row.audio_url,
        })),
    };
}

function printSummary(data) {
    console.log('SQLite source:', sqlitePath);
    for (const [table, rows] of Object.entries(data)) {
        console.log(`${table}: ${rows.length}`);
    }
}

async function main() {
    const data = loadSourceData();
    printSummary(data);

    if (dryRun) {
        console.log('Dry run complete. No remote changes applied.');
        return;
    }

    if (!serviceKey) {
        throw new Error('SUPABASE_SERVICE_KEY is required unless --dry-run is used');
    }

    await ensureRemoteSchemaReady();

    const deleteOrder = [
        'grammar_examples',
        'grammar_contexts',
        'grammar_meanings',
        'grammars',
    ];

    const insertOrder = [
        'grammars',
        'grammar_meanings',
        'grammar_contexts',
        'grammar_examples',
    ];

    console.log('Deleting existing remote grammar content...');
    for (const table of deleteOrder) {
        await deleteAll(table);
        console.log(`deleted ${table}`);
    }

    console.log('Uploading fresh grammar content...');
    for (const table of insertOrder) {
        await insertAll(table, data[table]);
        console.log(`inserted ${table}: ${data[table].length}`);
    }

    console.log('Migration complete.');
    console.log('Next step: run api/supabase/reset_content_identity_sequences.sql in Supabase SQL editor if you plan to keep using identity inserts.');
}

main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});