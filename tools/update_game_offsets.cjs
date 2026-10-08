#!/usr/bin/env node
'use strict';
// Generate reviewable candidates; dump identity alone cannot verify native hooks.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const catalog = require('../profiles/offset-catalog.json');
const hex = value => value == null ? 'UNRESOLVED' : `0x${value.toString(16).toUpperCase()}`;

function parseDump(text) {
    const types = new Map();
    let namespace = '', type;
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; ++i) {
        const line = lines[i];
        const ns = line.match(/^\/\/ Namespace: (.*)/);
        if (ns) { namespace = ns[1].trim(); continue; }
        const declaration = line.match(/^(?:public|private|internal|protected)?\s*(?:sealed |abstract |static )*(?:class|struct|enum|interface) (.+?)(?:\s*:.*?)? \/\/ TypeDefIndex: (\d+)/);
        if (declaration) {
            type = {name: (namespace ? namespace + '.' : '') + declaration[1].trim(), line: i + 1, fields: []};
            const bucket = types.get(type.name) || [];
            bucket.push(type); types.set(type.name, bucket);
        } else if (type) {
            const field = line.match(/^\s*(.*?)\s+([\w<>]+); \/\/ (0x[\da-fA-F]+)/);
            if (field) type.fields.push({name: field[2], declaration: field[1], offset: Number(field[3]), line: i + 1});
        }
    }
    return types;
}

function compare(dumpDirectory, variant) {
    const dump = fs.readFileSync(path.join(dumpDirectory, 'dump.cs'), 'utf8');
    const rawScript = fs.readFileSync(path.join(dumpDirectory, 'script.json'), 'utf8');
    const script = JSON.parse(rawScript);
    const types = parseDump(dump);
    const methods = new Map();
    for (const method of script.ScriptMethod || []) {
        const key = JSON.stringify([method.Name, method.Signature, method.TypeSignature]);
        const bucket = methods.get(key) || [];
        bucket.push(method); methods.set(key, bucket);
    }
    const report = {
        variant, source: path.basename(dumpDirectory),
        dumpSha256: crypto.createHash('sha256').update(dump).digest('hex'),
        scriptSha256: crypto.createHash('sha256').update(rawScript).digest('hex'),
        nativeVerified: false,
        methods: catalog.methods.map(reference => {
            const found = methods.get(JSON.stringify([reference.name, reference.signature, reference.typeSignature])) || [];
            const addresses = [...new Set(found.map(method => method.Address))];
            const address = addresses.length === 1 && Number.isSafeInteger(addresses[0]) && addresses[0] > 0 ? addresses[0] : null;
            return {...reference, target: address, candidates: addresses,
                status: address == null ? (found.length ? 'ambiguous' : 'missing') : 'matched-dump'};
        }),
        fields: catalog.fields.map(reference => {
            const matches = (types.get(reference.owner) || []).flatMap(type => type.fields)
                .filter(field => field.name === reference.name && field.declaration === reference.declaration);
            const field = matches.length === 1 ? matches[0] : null;
            return {...reference, target: field?.offset ?? null, targetLine: field?.line ?? null,
                status: field ? 'matched-dump' : (matches.length ? 'ambiguous' : 'missing')};
        }),
        nativeOnly: catalog.nativeOnly,
        unresolvedFieldIdentities: catalog.unresolvedFieldIdentities,
        warnings: catalog.warnings,
        unresolved: [],
    };
    report.unresolved = [...report.methods, ...report.fields].filter(item => item.target == null);
    return report;
}

function markdown(report) {
    const rows = [
        `# Menu offsets: ${report.source}`, '',
        'Các số dưới đây được đối chiếu bằng danh tính field hoặc tên + chữ ký hàm. Đây là dữ liệu từ dump, chưa xác minh opcode, hook, vtable hay chạy trên thiết bị.', '',
        `Matched methods: ${report.methods.filter(m => m.target != null).length}/${report.methods.length}. Matched fields: ${report.fields.filter(f => f.target != null).length}/${report.fields.length}.`, '',
        '## Fields', '', '| Owner / field | FF TH baseline | Target | dump.cs line |', '|---|---:|---:|---:|',
        ...report.fields.map(f => `| ${f.owner}.${f.name} | ${hex(f.baseline)} | ${hex(f.target)} | ${f.targetLine || ''} |`), '',
        '## Methods (RVA relative to the IL2CPP image)', '', '| Method | FF TH baseline | Target | Consumers |', '|---|---:|---:|---|',
        ...report.methods.map(m => `| ${m.name} | ${hex(m.baseline)} | ${hex(m.target)} | ${[...new Set(m.uses.map(u => u.file))].join(', ')} |`), '',
        '## Native verification required', '',
        ...report.nativeOnly.map(n => `- ${n.label}: FF TH ${hex(n.baseline)}. ${n.reason}`), '',
        ...report.unresolvedFieldIdentities.map(f => `- Raw access ${f.owner} + ${hex(f.offset)} has no unique direct field identity in the dump. Check inheritance or native layout before porting.`), '',
        ...report.warnings.map(w => `- ${w}`), '',
        'Không cộng delta chung và không dùng hash FF TH để xác nhận mã MAX. Các field Unity native/Il2CppClass, vị trí trong thân hàm và opcode cần binary đúng bản. OB mới đổi tên obfuscation sẽ được báo missing/ambiguous, cần tìm lại theo semantics và disassembly.', '',
        `dump.cs SHA-256: ${report.dumpSha256}`, `script.json SHA-256: ${report.scriptSha256}`, '',
    ];
    return rows.join('\n');
}

function headers(report) {
    if (report.unresolved.length) throw new Error(`Cannot emit headers: ${report.unresolved.length} unresolved identities.`);
    const fields = ['#pragma once', '#ifndef MIZZE_GAME_PROCESS_NAME', '#ifdef MIZZE_GAME_MAX',
        '#define MIZZE_GAME_PROCESS_NAME "FreeFireMAX"', '#else', '#define MIZZE_GAME_PROCESS_NAME "FreeFire"',
        '#endif', '#endif', '// Generated from exact managed-field identity; native validation is separate.', '#ifdef MIZZE_GAME_MAX'];
    for (const f of report.fields.filter(f => f.macro)) fields.push(`#define ${f.macro} ${hex(f.target)}`);
    fields.push('#else');
    for (const f of report.fields.filter(f => f.macro)) fields.push(`#define ${f.macro} ${hex(f.baseline)}`);
    fields.push('#endif', '#ifndef __ASSEMBLER__', '#include <cstdint>', 'namespace GameOffsets {',
        'constexpr uint64_t PlayerField(uint64_t th) {', '    switch (th) {');
    for (const f of report.fields.filter(f => f.owner === 'COW.GamePlay.Player')) fields.push(`        case ${hex(f.baseline)}: return ${f.macro};`);
    fields.push('        default: return th;', '    }', '}', '}', '#endif', '');
    const methods = ['#pragma once', '// Generated candidates, resolved by Name + Signature + TypeSignature.', '#include <cstdint>',
        'namespace GameOffsets {', 'constexpr uint64_t DumpRva(uint64_t th) {', '#ifdef MIZZE_GAME_MAX', '    switch (th) {'];
    for (const m of report.methods) methods.push(`        case ${hex(m.baseline)}: return ${hex(m.target)}; // ${m.name}`);
    methods.push('        default: return 0;', '    }', '#else', '    return th;', '#endif', '}', '}', '');
    return {fields: fields.join('\n'), methods: methods.join('\n')};
}

function main(argv) {
    const options = {};
    for (let i = 0; i < argv.length; ++i) {
        if (!['--dump', '--variant', '--out'].includes(argv[i]) || !argv[i + 1])
            throw new Error('Usage: node tools/update_game_offsets.cjs --dump DUMP_DIRECTORY --variant th|max --out OUTPUT_DIRECTORY');
        options[argv[i].slice(2)] = argv[++i];
    }
    if (!options.dump || !options.out || !['th', 'max'].includes(options.variant)) throw new Error('Required: --dump, --variant th|max, --out.');
    const report = compare(path.resolve(options.dump), options.variant);
    const destination = path.resolve(options.out);
    // Output is a candidate directory; never replace the live runtime headers implicitly.
    if (destination === path.resolve(__dirname, '../esp/Core')) throw new Error('Use a separate candidate directory for review.');
    fs.mkdirSync(destination, {recursive: true});
    // A reused directory must not retain old headers after a failed OB match.
    if (report.unresolved.length || options.variant !== 'max') {
        for (const name of ['GameProfileFields.h', 'GameProfileMethods.h']) {
            const file = path.join(destination, name);
            if (fs.existsSync(file)) fs.writeFileSync(file, '#error "Stale candidate: this scan did not resolve a complete MAX profile. Read offset-report.json."\n');
        }
    }
    fs.writeFileSync(path.join(destination, 'offset-report.json'), JSON.stringify(report, null, 2) + '\n');
    fs.writeFileSync(path.join(destination, 'offset-report.md'), markdown(report));
    // Runtime headers are a pair: TH baseline plus the MAX target. A TH report
    // alone must not silently install TH addresses into the MAX branch.
    if (!report.unresolved.length && options.variant === 'max') {
        const generated = headers(report);
        fs.writeFileSync(path.join(destination, 'GameProfileFields.h'), generated.fields);
        fs.writeFileSync(path.join(destination, 'GameProfileMethods.h'), generated.methods);
    }
    console.log(JSON.stringify({variant: report.variant, methods: report.methods.length,
        fields: report.fields.length, unresolved: report.unresolved.length,
        nativeVerified: false, output: destination}, null, 2));
    if (report.unresolved.length) process.exitCode = 2;
}

module.exports = {parseDump, compare, markdown, headers};
if (require.main === module) { try { main(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode = 1; } }
