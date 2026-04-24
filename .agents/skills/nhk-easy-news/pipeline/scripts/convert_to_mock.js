// convert_to_mock.js
// 遍历 data/{id}/processed.json，合并为 App 可用的 assets/mock/test_output.json 格式

const fs = require('fs');
const path = require('path');

const PIPELINE_DIR = path.resolve(__dirname, '..');
const DATA_DIR = path.join(PIPELINE_DIR, 'data');
const OUTPUT_PATH = path.resolve(PIPELINE_DIR, '../../assets/mock/test_output.json');

// 扫描所有文章文件夹
const articleDirs = fs.readdirSync(DATA_DIR)
    .filter(name => {
        const fullPath = path.join(DATA_DIR, name);
        return fs.statSync(fullPath).isDirectory() && fs.existsSync(path.join(fullPath, 'processed.json'));
    });

console.log(`📂 发现 ${articleDirs.length} 篇已处理文章`);

let existingArticles = [];
if (fs.existsSync(OUTPUT_PATH)) {
    try {
        existingArticles = JSON.parse(fs.readFileSync(OUTPUT_PATH, 'utf8'));
        console.log(`📝 读取到已存在的 ${existingArticles.length} 篇文章`);
    } catch (e) {
        console.warn(`⚠️ 无法解析已有的 test_output.json，将创建新文件。`);
    }
}

let updatedCount = 0;
let addedCount = 0;

for (const dirName of articleDirs) {
    const processedPath = path.join(DATA_DIR, dirName, 'processed.json');
    const processed = JSON.parse(fs.readFileSync(processedPath, 'utf8'));

    // 转换为 App 的 Article 数据模型格式
    const article = {
        id: processed.id,
        title: processed.title,
        clean_title: processed.clean_title || '',
        time: processed.time || null,
        audio_uri: processed.audio_uri || '',
        duration_ms: 0,
        items: []
    };

    // 从 sentences 转为 items，分配连续 index
    for (let i = 0; i < processed.sentences.length; i++) {
        const sentence = processed.sentences[i];
        article.items.push({
            text: sentence.original_text_with_ruby || sentence.clean_text || '',
            translation: sentence.translation || '',
            start_ms: sentence.start_ms,
            end_ms: sentence.end_ms,
            index: i,
            words: sentence.words.map(w => ({ ...w }))
        });
    }

    // 计算 duration_ms = 最后一句的 end_ms
    if (article.items.length > 0) {
        const lastEnd = article.items[article.items.length - 1].end_ms;
        if (lastEnd) article.duration_ms = lastEnd;
    }

    // 更新或追加
    const existingIndex = existingArticles.findIndex(a => a.id === article.id);
    if (existingIndex >= 0) {
        existingArticles[existingIndex] = article;
        updatedCount++;
    } else {
        existingArticles.push(article);
        addedCount++;
    }

    console.log(`  ✅ ${processed.id}: ${article.items.length} 句, ${article.items.reduce((n, i) => n + i.words.length, 0)} 词`);
}

// 按照 time 降序排序
existingArticles.sort((a, b) => {
    const timeA = new Date(a.time || 0).getTime();
    const timeB = new Date(b.time || 0).getTime();
    return timeB - timeA;
});

fs.writeFileSync(OUTPUT_PATH, JSON.stringify(existingArticles, null, 2), 'utf8');
console.log(`\n🎉 转换完成：新增 ${addedCount} 篇，更新 ${updatedCount} 篇。总计 ${existingArticles.length} 篇文章 → ${OUTPUT_PATH}`);
