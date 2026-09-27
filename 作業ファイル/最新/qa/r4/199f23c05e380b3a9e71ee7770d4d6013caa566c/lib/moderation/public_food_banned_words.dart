/// Fixed banned words for public food names.
///
/// One list, checked at publish time and when a public row's name changes.
/// There is no admin editor and no remote dictionary.
const List<String> publicFoodBannedWords = <String>[
  'fuck',
  'fucking',
  'motherfucker',
  'shit',
  'bullshit',
  'asshole',
  'bitch',
  'bastard',
  'cunt',
  'dick',
  'cock',
  'pussy',
  'whore',
  'slut',
  'nigger',
  'nigga',
  'faggot',
  'retard',
  'rape',
  'くそ',
  'くそったれ',
  'ちくしょう',
  'ちんこ',
  'ちんぽ',
  'まんこ',
  'うんこ',
  'きんたま',
  'ファック',
  'セックス',
  'フェラ',
  '中出し',
  '死ね',
  '殺す',
  'きちがい',
  '池沼',
  'エロ',
  // Compounds that the short boundary-only fragments do not catch.
  // くそ / えろ stay boundary-only so they do not reject ordinary foods.
  'くそまずい',
  'くそ不味い',
  'えろい',
  'えろすぎ',
  'えろえろ',
  // Full explicit compounds. Not boundary-only, so they match as substrings.
  'おまんこ',
  'フェラチオ',
  'イラマチオ',
  'クンニ',
  'パイズリ',
  '顔射',
  'ザーメン',
  'オナニー',
  '素股',
  '手コキ',
  '手マン',
  '肉便器',
  'fellatio',
  'cunnilingus',
];

/// Halfwidth katakana, mapped to hiragana. Both strings are the same length.
const String publicFoodHalfwidthKatakanaFrom =
    'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';

const String publicFoodHalfwidthKatakanaTo =
    'をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん';

/// 1:1 confusable fold applied after NFKC. Both strings are the same length.
/// Accents, Cyrillic/Latin lookalikes, and symbol/digit substitutions.
/// Kept identical to the translate() pair in the banned-name migration.
const String publicFoodConfusableFrom =
    'àáâãäåÀÁÂÃÄÅèéêëÈÉÊËìíîïÌÍÎÏòóôõöÒÓÔÕÖùúûüÙÚÛÜýÿÝŸñÑçÇаАеЕоОрРсСуУхХіІјЈѕЅԁԀ013457@\$!';

const String publicFoodConfusableTo =
    'aaaaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuyyyynnccaaeeooppccyyxxiijjssddoieastasi';

/// Halfwidth katakana bases that take a dakuten (U+FF9E), and the fullwidth
/// katakana they become. Both strings are the same length. Applied before NFKC.
const String publicFoodHalfwidthDakutenBase = 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ';

const String publicFoodHalfwidthDakutenTo = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ';

/// Halfwidth katakana bases that take a handakuten (U+FF9F).
const String publicFoodHalfwidthHandakutenBase = 'ﾊﾋﾌﾍﾎ';

const String publicFoodHalfwidthHandakutenTo = 'パピプペポ';

/// Normalized terms that match only on a word boundary.
/// Longer Japanese terms still match as substrings.
const List<String> publicFoodBoundaryOnlyTerms = <String>[
  'えろ',
  'くそ',
  'ふぇら',
  'まんこ',
];

/// Normalized phrases removed before the banned-word scan.
/// A banned word beside one of these phrases is still rejected.
const List<String> publicFoodAllowedPhrases = <String>[
  'cock tail',
  'rape seed',
];
