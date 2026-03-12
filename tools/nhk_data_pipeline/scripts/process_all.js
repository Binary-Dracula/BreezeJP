// process_all.js
// 遍历 data/ 下所有文章文件夹，读取 raw.json，
// 用 Kuromoji 分词处理，输出 processed.json
// 确保 processed.json 的 sentences 数量与 raw.json 严格一致

const fs = require('fs');
const path = require('path');
const kuromoji = require('kuromoji');

const PIPELINE_DIR = path.resolve(__dirname, '..');
const DATA_DIR = path.join(PIPELINE_DIR, 'data');

// 片假名转平假名
function katakanaToHiragana(kata) {
    return kata.replace(/[\u30a1-\u30f6]/g, function (match) {
        return String.fromCharCode(match.charCodeAt(0) - 0x60);
    });
}

// 转义正则特殊字符
function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * 生成精确的 ruby_text 注音字符串。
 * 只在汉字部分标注假名，送假名/纯假名保持原样。
 */
function generateRubyText(surfaceForm, reading) {
    if (!/[\u4e00-\u9faf\u3005]/.test(surfaceForm)) {
        return surfaceForm;
    }
    if (!reading) return surfaceForm;

    const hiraganaReading = katakanaToHiragana(reading);

    // 将 surface_form 按汉字/非汉字交替拆分为段
    const segments = [];
    let idx = 0;
    while (idx < surfaceForm.length) {
        const isKanjiChar = /[\u4e00-\u9faf\u3005]/.test(surfaceForm[idx]);
        let seg = '';
        while (idx < surfaceForm.length && /[\u4e00-\u9faf\u3005]/.test(surfaceForm[idx]) === isKanjiChar) {
            seg += surfaceForm[idx];
            idx++;
        }
        segments.push({ text: seg, isKanji: isKanjiChar });
    }

    // 构建正则
    let regexParts = [];
    let lastKanjiIndex = -1;
    for (let j = 0; j < segments.length; j++) {
        if (segments[j].isKanji) lastKanjiIndex = j;
    }

    for (let j = 0; j < segments.length; j++) {
        if (segments[j].isKanji) {
            regexParts.push(j === lastKanjiIndex ? '(.+)' : '(.+?)');
        } else {
            regexParts.push(escapeRegex(katakanaToHiragana(segments[j].text)));
        }
    }

    const regex = new RegExp('^' + regexParts.join('') + '$');
    const match = hiraganaReading.match(regex);

    if (!match) {
        return surfaceForm + '[' + hiraganaReading + ']';
    }

    let result = '';
    let groupIdx = 1;
    for (const seg of segments) {
        if (seg.isKanji) {
            result += seg.text + '[' + match[groupIdx] + ']';
            groupIdx++;
        } else {
            result += seg.text;
        }
    }
    return result;
}

/**
 * 处理单篇文章：读取 raw.json，用 Kuromoji 分词，输出 processed.json
 */
function processArticle(articleDir, tokenizer) {
    const rawPath = path.join(articleDir, 'raw.json');
    const alignedPath = path.join(articleDir, 'aligned.json');
    const processedPath = path.join(articleDir, 'processed.json');

    if (!fs.existsSync(rawPath)) {
        console.log(`  ⏭️ 跳过 ${path.basename(articleDir)}（无 raw.json）`);
        return false;
    }

    const rawData = JSON.parse(fs.readFileSync(rawPath, 'utf8'));
    const articleId = rawData.id;

    // 读取对齐数据（可选）
    let alignedItems = [];
    if (fs.existsSync(alignedPath)) {
        const alignedData = JSON.parse(fs.readFileSync(alignedPath, 'utf8'));
        alignedItems = alignedData.items || alignedData.sentences || [];
        console.log(`  🔄 处理 ${articleId}: ${rawData.sentences.length} 句 (有对齐数据: ${alignedItems.length} 条)`);
    } else {
        console.log(`  🔄 处理 ${articleId}: ${rawData.sentences.length} 句 (无对齐数据，时间戳将为空)`);
    }

    const processedSentences = [];

    rawData.sentences.forEach((sentenceText, index) => {
        // 移除假名注音得到纯文本
        const cleanText = sentenceText.replace(/\[.*?\]/g, '');

        // 用 Kuromoji 分词
        const tokens = tokenizer.tokenize(cleanText);

        const words = tokens.map(t => {
            const hasKanji = /[\u4e00-\u9faf\u3005]/.test(t.surface_form);
            let furigana = "";
            let ruby_text = t.surface_form;

            if (hasKanji && t.reading) {
                furigana = katakanaToHiragana(t.reading);
                ruby_text = generateRubyText(t.surface_form, t.reading);
            }

            return {
                ...t,
                furigana: furigana,
                ruby_text: ruby_text
            };
        });

        // 从对齐数据中查找匹配的时间戳和翻译
        let start_ms = null;
        let end_ms = null;
        let translation = "";

        if (alignedItems.length > 0) {
            // 优先用 index 匹配，其次用文本内容匹配
            const byIndex = alignedItems.find(item => item.index === index);
            const byText = alignedItems.find(item => {
                const itemClean = (item.text || item.clean_text || '').replace(/\[.*?\]/g, '');
                return itemClean.includes(cleanText) || cleanText.includes(itemClean);
            });
            const matched = byIndex || byText;
            if (matched) {
                start_ms = matched.start_ms ?? null;
                end_ms = matched.end_ms ?? null;
                translation = matched.translation || "";
            }
        }

        processedSentences.push({
            original_text_with_ruby: sentenceText,
            clean_text: cleanText,
            translation: translation,
            start_ms: start_ms,
            end_ms: end_ms,
            index: index,
            words: words
        });
    });

    // 验证句子数量一致
    if (processedSentences.length !== rawData.sentences.length) {
        console.error(`  ❌ 句子数量不一致！raw: ${rawData.sentences.length}, processed: ${processedSentences.length}`);
        return false;
    }

    const processedData = {
        id: rawData.id,
        title: rawData.title,
        clean_title: rawData.clean_title || "",
        time: rawData.time,
        audio_uri: rawData.audio_uri,
        sentences: processedSentences
    };

    fs.writeFileSync(processedPath, JSON.stringify(processedData, null, 2), 'utf8');
    console.log(`  ✅ → ${articleId}/processed.json (${processedSentences.length} 句, ${processedSentences.reduce((n, s) => n + s.words.length, 0)} 词)`);
    return true;
}

// --- 主流程 ---
kuromoji.builder({ dicPath: 'node_modules/kuromoji/dict' }).build(function (err, tokenizer) {
    if (err) {
        console.error("❌ 加载 Kuromoji 字典时出错:", err);
        return;
    }

    console.log("🚀 Kuromoji 分词处理（批量）");

    // 扫描 data/ 下所有文章文件夹
    if (!fs.existsSync(DATA_DIR)) {
        console.error(`❌ 数据目录不存在: ${DATA_DIR}`);
        return;
    }

    const articleDirs = fs.readdirSync(DATA_DIR)
        .filter(name => {
            const fullPath = path.join(DATA_DIR, name);
            return fs.statSync(fullPath).isDirectory() && fs.existsSync(path.join(fullPath, 'raw.json'));
        })
        .map(name => path.join(DATA_DIR, name));

    console.log(`📂 发现 ${articleDirs.length} 篇文章待处理\n`);

    let successCount = 0;
    for (const dir of articleDirs) {
        if (processArticle(dir, tokenizer)) {
            successCount++;
        }
    }

    console.log(`\n🎉 处理完成！成功 ${successCount}/${articleDirs.length} 篇`);
});
