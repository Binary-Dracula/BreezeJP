import 'reference_models.dart';

class ReferenceData {
  static const List<ReferenceGroup> numbers = [
    ReferenceGroup(
      title: '基本数字 (1-10)',
      items: [
        ReferenceItem(character: '1', kana: 'いち', romaji: 'ichi'),
        ReferenceItem(character: '2', kana: 'に', romaji: 'ni'),
        ReferenceItem(character: '3', kana: 'さん', romaji: 'san'),
        ReferenceItem(
          character: '4',
          kana: 'よん / し',
          romaji: 'yon / shi',
          isIrregular: true,
        ),
        ReferenceItem(character: '5', kana: 'ご', romaji: 'go'),
        ReferenceItem(character: '6', kana: 'ろく', romaji: 'roku'),
        ReferenceItem(
          character: '7',
          kana: 'なな / しち',
          romaji: 'nana / shichi',
          isIrregular: true,
        ),
        ReferenceItem(character: '8', kana: 'はち', romaji: 'hachi'),
        ReferenceItem(
          character: '9',
          kana: 'きゅう / く',
          romaji: 'kyuu / ku',
          isIrregular: true,
        ),
        ReferenceItem(character: '10', kana: 'じゅう', romaji: 'juu'),
      ],
    ),
    ReferenceGroup(
      title: '百位数 (100-900)',
      items: [
        ReferenceItem(character: '100', kana: 'ひゃく', romaji: 'hyaku'),
        ReferenceItem(character: '200', kana: 'にひゃく', romaji: 'nihyaku'),
        ReferenceItem(
          character: '300',
          kana: 'さんびゃく',
          romaji: 'sanbyaku',
          isIrregular: true,
        ),
        ReferenceItem(character: '400', kana: 'よんひゃく', romaji: 'yonhyaku'),
        ReferenceItem(character: '500', kana: 'ごひゃく', romaji: 'gohyaku'),
        ReferenceItem(
          character: '600',
          kana: 'ろっぴゃく',
          romaji: 'roppyaku',
          isIrregular: true,
        ),
        ReferenceItem(character: '700', kana: 'ななひゃく', romaji: 'nanahyaku'),
        ReferenceItem(
          character: '800',
          kana: 'はっぴゃく',
          romaji: 'happyaku',
          isIrregular: true,
        ),
        ReferenceItem(character: '900', kana: 'きゅうひゃく', romaji: 'kyuuhyaku'),
      ],
    ),
    ReferenceGroup(
      title: '千位数 (1000-9000)',
      items: [
        ReferenceItem(character: '1000', kana: 'せん', romaji: 'sen'),
        ReferenceItem(character: '2000', kana: 'にせん', romaji: 'nisen'),
        ReferenceItem(
          character: '3000',
          kana: 'さんぜん',
          romaji: 'sanzen',
          isIrregular: true,
        ),
        ReferenceItem(character: '4000', kana: 'よんせん', romaji: 'yonsen'),
        ReferenceItem(character: '5000', kana: 'ごせん', romaji: 'gosen'),
        ReferenceItem(character: '6000', kana: 'ろくせん', romaji: 'rokusen'),
        ReferenceItem(character: '7000', kana: 'ななせん', romaji: 'nanasen'),
        ReferenceItem(
          character: '8000',
          kana: 'はっせん',
          romaji: 'hassen',
          isIrregular: true,
        ),
        ReferenceItem(character: '9000', kana: 'きゅうせん', romaji: 'kyuusen'),
      ],
    ),
    ReferenceGroup(
      title: '大数',
      items: [
        ReferenceItem(character: '1万', kana: 'いちまん', romaji: 'ichi man'),
        ReferenceItem(character: '1亿', kana: 'いちおく', romaji: 'ichi oku'),
      ],
    ),
  ];

  static const List<ReferenceGroup> datesAndMonths = [
    ReferenceGroup(
      title: '月份 (月 - がつ)',
      items: [
        ReferenceItem(character: '1月', kana: 'いちがつ', romaji: 'ichigatsu'),
        ReferenceItem(character: '2月', kana: 'にがつ', romaji: 'nigatsu'),
        ReferenceItem(character: '3月', kana: 'さんがつ', romaji: 'sangatsu'),
        ReferenceItem(
          character: '4月',
          kana: 'しがつ',
          romaji: 'shigatsu',
          isIrregular: true,
        ),
        ReferenceItem(character: '5月', kana: 'ごがつ', romaji: 'gogatsu'),
        ReferenceItem(character: '6月', kana: 'ろくがつ', romaji: 'rokugatsu'),
        ReferenceItem(
          character: '7月',
          kana: 'しちがつ',
          romaji: 'shichigatsu',
          isIrregular: true,
        ),
        ReferenceItem(character: '8月', kana: 'はちがつ', romaji: 'hachigatsu'),
        ReferenceItem(
          character: '9月',
          kana: 'くがつ',
          romaji: 'kugatsu',
          isIrregular: true,
        ),
        ReferenceItem(character: '10月', kana: 'じゅうがつ', romaji: 'juugatsu'),
        ReferenceItem(
          character: '11月',
          kana: 'じゅういちがつ',
          romaji: 'juuichigatsu',
        ),
        ReferenceItem(character: '12月', kana: 'じゅうにがつ', romaji: 'juunigatsu'),
      ],
    ),
    ReferenceGroup(
      title: '日期 (1日 - 10日)',
      items: [
        ReferenceItem(
          character: '1日',
          kana: 'ついたち',
          romaji: 'tsuitachi',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '2日',
          kana: 'ふつか',
          romaji: 'futsuka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '3日',
          kana: 'みっか',
          romaji: 'mikka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '4日',
          kana: 'よっか',
          romaji: 'yokka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '5日',
          kana: 'いつか',
          romaji: 'itsuka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '6日',
          kana: 'むいか',
          romaji: 'muika',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '7日',
          kana: 'なのか',
          romaji: 'nanoka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '8日',
          kana: 'ようか',
          romaji: 'youka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '9日',
          kana: 'ここのか',
          romaji: 'kokonoka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '10日',
          kana: 'とおか',
          romaji: 'tooka',
          isIrregular: true,
        ),
      ],
    ),
    ReferenceGroup(
      title: '特殊日期 (11日之后)',
      items: [
        ReferenceItem(
          character: '14日',
          kana: 'じゅうよっか',
          romaji: 'juuyokka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '20日',
          kana: 'はつか',
          romaji: 'hatsuka',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '24日',
          kana: 'にじゅうよっか',
          romaji: 'nijuuyokka',
          isIrregular: true,
        ),
      ],
    ),
  ];

  static const List<ReferenceGroup> time = [
    ReferenceGroup(
      title: '小时 (時 - じ)',
      items: [
        ReferenceItem(character: '1時', kana: 'いちじ', romaji: 'ichiji'),
        ReferenceItem(character: '2時', kana: 'にじ', romaji: 'niji'),
        ReferenceItem(character: '3時', kana: 'さんじ', romaji: 'sanji'),
        ReferenceItem(
          character: '4時',
          kana: 'よじ',
          romaji: 'yoji',
          isIrregular: true,
        ),
        ReferenceItem(character: '5時', kana: 'ごじ', romaji: 'goji'),
        ReferenceItem(character: '6時', kana: 'ろくじ', romaji: 'rokuji'),
        ReferenceItem(
          character: '7時',
          kana: 'しちじ',
          romaji: 'shichiji',
          isIrregular: true,
        ),
        ReferenceItem(character: '8時', kana: 'はちじ', romaji: 'hachiji'),
        ReferenceItem(
          character: '9時',
          kana: 'くじ',
          romaji: 'kuji',
          isIrregular: true,
        ),
        ReferenceItem(character: '10時', kana: 'じゅうじ', romaji: 'juuji'),
        ReferenceItem(character: '11時', kana: 'じゅういちじ', romaji: 'juuichiji'),
        ReferenceItem(character: '12時', kana: 'じゅうにじ', romaji: 'juuniji'),
      ],
    ),
    ReferenceGroup(
      title: '分钟 (分 - ふん/ぷん)',
      items: [
        ReferenceItem(
          character: '1分',
          kana: 'いっぷん',
          romaji: 'ippun',
          isIrregular: true,
        ),
        ReferenceItem(character: '2分', kana: 'にふん', romaji: 'nifun'),
        ReferenceItem(
          character: '3分',
          kana: 'さんぷん',
          romaji: 'sanpun',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '4分',
          kana: 'よんぷん',
          romaji: 'yonpun',
          isIrregular: true,
        ),
        ReferenceItem(character: '5分', kana: 'ごふん', romaji: 'gofun'),
        ReferenceItem(
          character: '6分',
          kana: 'ろっぷん',
          romaji: 'roppun',
          isIrregular: true,
        ),
        ReferenceItem(character: '7分', kana: 'ななふん', romaji: 'nanafun'),
        ReferenceItem(
          character: '8分',
          kana: 'はっぷん',
          romaji: 'happun',
          isIrregular: true,
        ),
        ReferenceItem(character: '9分', kana: 'きゅうふん', romaji: 'kyuufun'),
        ReferenceItem(
          character: '10分',
          kana: 'じゅっぷん',
          romaji: 'juppun',
          isIrregular: true,
        ),
        ReferenceItem(character: '15分', kana: 'じゅうごふん', romaji: 'juugofun'),
        ReferenceItem(
          character: '30分 (半)',
          kana: 'さんじゅっぷん / はん',
          romaji: 'sanjuppun / han',
          isIrregular: true,
        ),
      ],
    ),
  ];

  static const List<ReferenceGroup> counters = [
    ReferenceGroup(
      title: '通用量词 (个 - つ)',
      items: [
        ReferenceItem(
          character: '1つ',
          kana: 'ひとつ',
          romaji: 'hitotsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '2つ',
          kana: 'ふたつ',
          romaji: 'futatsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '3つ',
          kana: 'みっつ',
          romaji: 'mittsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '4つ',
          kana: 'よっつ',
          romaji: 'yottsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '5つ',
          kana: 'いつつ',
          romaji: 'itsutsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '6つ',
          kana: 'むっつ',
          romaji: 'muttsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '7つ',
          kana: 'ななつ',
          romaji: 'nanatsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '8つ',
          kana: 'やっつ',
          romaji: 'yattsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '9つ',
          kana: 'ここのつ',
          romaji: 'kokonotsu',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '10',
          kana: 'とお',
          romaji: 'too',
          isIrregular: true,
        ),
      ],
    ),
    ReferenceGroup(
      title: '人 (にん)',
      items: [
        ReferenceItem(
          character: '1人',
          kana: 'ひとり',
          romaji: 'hitori',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '2人',
          kana: 'ふたり',
          romaji: 'futari',
          isIrregular: true,
        ),
        ReferenceItem(character: '3人', kana: 'さんにん', romaji: 'sannin'),
        ReferenceItem(
          character: '4人',
          kana: 'よにん',
          romaji: 'yonin',
          isIrregular: true,
        ),
      ],
    ),
    ReferenceGroup(
      title: '细长物 (本 - ほん/ぽん/ぼん)',
      subtitle: '用于：笔、伞、树木、瓶子等',
      items: [
        ReferenceItem(
          character: '1本',
          kana: 'いっぽん',
          romaji: 'ippon',
          isIrregular: true,
        ),
        ReferenceItem(character: '2本', kana: 'にほん', romaji: 'nihon'),
        ReferenceItem(
          character: '3本',
          kana: 'さんぼん',
          romaji: 'sanbon',
          isIrregular: true,
        ),
        ReferenceItem(character: '4本', kana: 'よんほん', romaji: 'yonhon'),
        ReferenceItem(character: '5本', kana: 'ごほん', romaji: 'gohon'),
        ReferenceItem(
          character: '6本',
          kana: 'ろっぽん',
          romaji: 'roppon',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '8本',
          kana: 'はっぽん',
          romaji: 'happon',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '10本',
          kana: 'じゅっぽん',
          romaji: 'juppon',
          isIrregular: true,
        ),
      ],
    ),
    ReferenceGroup(
      title: '扁平物 (枚 - まい)',
      subtitle: '用于：纸张、衬衫、盘子等 (无特殊音变)',
      items: [
        ReferenceItem(character: '1枚', kana: 'いちまい', romaji: 'ichimai'),
        ReferenceItem(character: '2枚', kana: 'にまい', romaji: 'nimai'),
        ReferenceItem(character: '3枚', kana: 'さんまい', romaji: 'sanmai'),
      ],
    ),
    ReferenceGroup(
      title: '小动物 (匹 - ひき/ぴき/びき)',
      subtitle: '用于：狗、猫、鱼、昆虫等',
      items: [
        ReferenceItem(
          character: '1匹',
          kana: 'いっぴき',
          romaji: 'ippiki',
          isIrregular: true,
        ),
        ReferenceItem(character: '2匹', kana: 'にひき', romaji: 'nihiki'),
        ReferenceItem(
          character: '3匹',
          kana: 'さんびき',
          romaji: 'sanbiki',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '6匹',
          kana: 'ろっぴき',
          romaji: 'roppiki',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '8匹',
          kana: 'はっぴき',
          romaji: 'happiki',
          isIrregular: true,
        ),
        ReferenceItem(
          character: '10匹',
          kana: 'じゅっぴき',
          romaji: 'juppiki',
          isIrregular: true,
        ),
      ],
    ),
  ];
}
