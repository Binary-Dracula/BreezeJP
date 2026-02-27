const fs = require('fs');
const kuromoji = require('kuromoji');

// 构造 kuromoji 分词器
kuromoji.builder({ dicPath: 'node_modules/kuromoji/dict' }).build(function (err, tokenizer) {
    if (err) {
        console.error("加载 Kuromoji 字典时出错:", err);
        return;
    }

    // 读取JSON文件
    const data = JSON.parse(fs.readFileSync('data/test_output.json', 'utf8'));
    const alignedData = JSON.parse(fs.readFileSync('data/test_output_aligned.json', 'utf8'));

    // 将 aligned 数据转为一个便于查询的 map (按 article id 分组)
    const alignedMap = {};
    alignedData.forEach(article => {
        alignedMap[article.id] = article;
    });

    // 取第一篇文章进行处理和测试
    const firstArticle = data[0];
    const firstArticleAligned = alignedMap[firstArticle.id] || {};
    const firstArticleAlignedItems = firstArticleAligned.items || [];

    const result = {
        id: firstArticle.id,
        title: firstArticle.title,
        audio_uri: firstArticleAligned.audio_uri || "",
        sentences: []
    };

    firstArticle.paragraphs.forEach(paragraph => {
        // 按照句号进行句子分割，保留句号本身
        const rawSentences = paragraph.split(/(。)/).filter(s => s.trim().length > 0);

        // 将句号拼接回前面的句子
        const mergedSentences = [];
        for (let i = 0; i < rawSentences.length; i++) {
            if (rawSentences[i] === '。') {
                if (mergedSentences.length > 0) {
                    mergedSentences[mergedSentences.length - 1] += '。';
                } else {
                    mergedSentences.push('。');
                }
            } else {
                mergedSentences.push(rawSentences[i]);
            }
        }

        mergedSentences.forEach(sentenceText => {
            // 移除原有的假名注音 (例如: 高市[たかいち] => 高市) 以便提供干净的纯文本给Kuromoji进行分词
            const cleanText = sentenceText.replace(/\[.*?\]/g, '');

            // 使用Kuromoji对纯文本进行分词
            const tokens = tokenizer.tokenize(cleanText);

            // 片假名转平假名工具函数
            const katakanaToHiragana = (kata) => {
                return kata.replace(/[\u30a1-\u30f6]/g, function (match) {
                    const chr = match.charCodeAt(0) - 0x60;
                    return String.fromCharCode(chr);
                });
            };

            // 转义正则特殊字符
            const escapeRegex = (str) => str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

            /**
             * 生成精确的 ruby_text 注音字符串。
             * 只在汉字部分标注假名，送假名/纯假名保持原样。
             * 例如: surface_form="増える", reading="フエル" → "増[ふ]える"
             *       surface_form="考え方", reading="カンガエカタ" → "考[かんが]え方[かた]"
             *       surface_form="総理",   reading="ソウリ" → "総理[そうり]"
             */
            const generateRubyText = (surfaceForm, reading) => {
                // 无汉字则不需要注音，直接返回原文
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

                // 构建正则：汉字段 → 捕获组 (.+?)，非汉字段 → 字面量匹配
                // 最后一个汉字捕获组使用贪婪匹配 (.+)
                let regexParts = [];
                let lastKanjiIndex = -1;
                for (let j = 0; j < segments.length; j++) {
                    if (segments[j].isKanji) lastKanjiIndex = j;
                }

                for (let j = 0; j < segments.length; j++) {
                    if (segments[j].isKanji) {
                        regexParts.push(j === lastKanjiIndex ? '(.+)' : '(.+?)');
                    } else {
                        // 非汉字段需要转换为平假名后做匹配（处理片假名送假名的情况）
                        regexParts.push(escapeRegex(katakanaToHiragana(segments[j].text)));
                    }
                }

                const regex = new RegExp('^' + regexParts.join('') + '$');
                const match = hiraganaReading.match(regex);

                if (!match) {
                    // 匹配失败时回退：整词注音
                    return surfaceForm + '[' + hiraganaReading + ']';
                }

                // 用捕获组结果拼接: 汉字[读音] + 非汉字原样
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
            };

            const words = tokens.map(t => {
                // 判断表层形式中是否包含日文汉字 (或 々)
                const hasKanji = /[\u4e00-\u9faf\u3005]/.test(t.surface_form);
                let furigana = "";
                let ruby_text = t.surface_form; // 默认值：无注音的原文

                if (hasKanji && t.reading) {
                    furigana = katakanaToHiragana(t.reading);
                    ruby_text = generateRubyText(t.surface_form, t.reading);
                }

                return {
                    ...t,
                    furigana: furigana,    // 整词平假名读音（纯假名为空）
                    ruby_text: ruby_text   // 精确注音格式，如 増[ふ]える，可直接供 ruby_text 使用
                };
            });

            // 尝试在 aligned 数据中寻找匹配的翻译和时间戳
            let translation = "";
            let start_ms = null;
            let end_ms = null;
            let index = null;
            const matchedItem = firstArticleAlignedItems.find(item => item.text.includes(sentenceText));
            if (matchedItem) {
                translation = matchedItem.translation;
                start_ms = matchedItem.start_ms;
                end_ms = matchedItem.end_ms;
                index = matchedItem.index;
            }

            result.sentences.push({
                original_text_with_ruby: sentenceText,
                clean_text: cleanText,
                translation: translation,
                start_ms: start_ms,
                end_ms: end_ms,
                index: index,
                words: words
            });
        });
    });

    // 将结果输出到 JSON 文件
    fs.writeFileSync('data/test_kuromoji_output.json', JSON.stringify(result, null, 2), 'utf8');
    console.log("处理完成！结果已保存到 'data/test_kuromoji_output.json'");
});
