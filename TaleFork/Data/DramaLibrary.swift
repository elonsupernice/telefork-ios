import Foundation

enum DramaLibrary {
    static let dramas: [Drama] = [beforeRainStops, silentFrequency, borrowedTomorrow]

    static func drama(id: String) -> Drama? { dramas.first { $0.id == id } }

    static let beforeRainStops = Drama(
        id: "before-rain-stops",
        title: copy("雨停之前", "Before the Rain Stops", "雨が止む前に"),
        subtitle: copy("一封寄給十年前的信，在末班電車上被打開。", "A letter addressed to ten years ago is opened on the last tram.", "十年前に宛てた手紙が、終電で開かれる。"),
        synopsis: copy(
            "記者林澄收到一封沒有寄件人的藍色信件，信中只寫著：在雨停前搭上零點電車。她原以為這是失蹤案件的新線索，直到車上的舊電話響起，而那個她以為永遠不會再見的人出現在車尾。每一次選擇，都會改變黎明到來時留下的人。",
            "Reporter Lin Cheng receives an unsigned blue letter telling her to board the midnight tram before the rain stops. She expects a clue to a disappearance—until an old telephone rings and someone she thought she had lost appears at the rear of the car. Every choice changes who remains when dawn arrives.",
            "記者リン・チェンに届いた差出人不明の青い手紙。『雨が止む前に零時の電車へ』。失踪事件の手掛かりだと思った彼女を、古い電話のベルと、二度と会えないはずの人物が待っていた。選択のたび、夜明けに残る人が変わる。"
        ),
        genre: copy("都會懸疑", "Urban Mystery", "都市ミステリー"),
        tags: [copy("互動", "Interactive", "インタラクティブ"), copy("情感", "Emotional", "感情"), copy("雙結局", "Two Endings", "二つの結末")],
        year: 2026,
        posterImageName: "rain-stop-arrival.png",
        accentHex: "F1B65C",
        availability: .available,
        entryEpisodeID: "rain-01",
        episodes: [
            DramaEpisode(
                id: "rain-01", number: 1,
                title: copy("零點來信", "The Midnight Letter", "零時の手紙"),
                sceneCaption: copy("雨夜，林澄按信上的時間來到海邊電車站。", "On a rain-soaked night, Lin Cheng reaches the seaside tram stop at the time written in the letter.", "雨の夜、リン・チェンは手紙に記された時刻に海辺の停留所へ着く。"),
                clipName: "rain-01-arrival", durationSeconds: 6,
                choices: [choice("board", "登上末班電車", "答案可能就在車上", "Board the last tram", "The answer may be waiting inside", "終電に乗る", "答えは車内にあるかもしれない", "rain-02")], ending: nil
            ),
            DramaEpisode(
                id: "rain-02", number: 2,
                title: copy("無人接聽", "No One Answers", "応答なし"),
                sceneCaption: copy("車廂裡只有她、藍色信件，和一部突然響起的舊電話。", "The car holds only her, the blue letter, and an old telephone that suddenly starts ringing.", "車内には彼女と青い手紙、そして突然鳴り出す古い電話だけ。"),
                clipName: "rain-02-letter", durationSeconds: 6,
                choices: [
                    choice("follow", "走向車尾的人影", "先確認誰在跟蹤你", "Follow the figure", "Find out who is watching you", "車両後方の影を追う", "誰が見ているのか確かめる", "rain-03"),
                    choice("answer", "接起舊電話", "聽完那通等了十年的電話", "Answer the telephone", "Hear the call that waited ten years", "電話を取る", "十年待ち続けた声を聞く", "rain-04")
                ], ending: nil
            ),
            DramaEpisode(
                id: "rain-03", number: 3,
                title: copy("失約的人", "The One Who Vanished", "消えた約束"),
                sceneCaption: copy("人影轉身。周岑手裡握著和信封火漆相同的銅章。", "The figure turns. Zhou Cen holds a brass token bearing the same seal as the letter.", "影が振り向く。ジョウ・ツェンの手には、封蝋と同じ紋章の真鍮札。"),
                clipName: "rain-03-meeting", durationSeconds: 6,
                choices: [
                    choice("trust", "相信他一次", "把信交給他，一起面對真相", "Trust him once", "Give him the letter and face the truth", "もう一度信じる", "手紙を渡し、真実と向き合う", "rain-05"),
                    choice("leave", "帶著信離開", "保留真相，也保留距離", "Leave with the letter", "Keep the truth—and the distance", "手紙を持って去る", "真実も距離も手元に残す", "rain-06")
                ], ending: nil
            ),
            DramaEpisode(
                id: "rain-04", number: 4,
                title: copy("延遲十年的聲音", "A Voice Ten Years Late", "十年遅れの声"),
                sceneCaption: copy("電話裡是林澄自己的錄音：不要再讓沉默替你做選擇。", "The voice is Lin Cheng's own recording: don't let silence make the choice again.", "聞こえたのは自分の録音。もう沈黙に選ばせないで。"),
                clipName: "rain-04-answer", durationSeconds: 6,
                choices: [
                    choice("return", "回到車尾找他", "這次由你先開口", "Find him at the rear car", "This time, you speak first", "彼を探しに戻る", "今度は自分から話す", "rain-05"),
                    choice("listen", "聽到最後", "接受有些答案只能獨自承擔", "Listen to the end", "Accept that some truths are carried alone", "最後まで聞く", "一人で背負う真実もある", "rain-06")
                ], ending: nil
            ),
            DramaEpisode(
                id: "rain-05", number: 5,
                title: copy("雨後同站", "The Same Stop at Dawn", "雨上がりの同じ駅"),
                sceneCaption: copy("黎明前，兩個人終於把當年的沉默說完。", "Before dawn, they finally finish the conversation silence interrupted years ago.", "夜明け前、二人はあの日途切れた言葉を最後まで話す。"),
                clipName: "rain-05-dawn", durationSeconds: 6, choices: [],
                ending: DramaEnding(title: copy("共同到站", "Arriving Together", "共に到着"), summary: copy("真相沒有改變過去，但讓他們能一起走向下一站。", "The truth cannot change the past, but it lets them walk toward the next stop together.", "真実は過去を変えない。それでも二人は次の駅へ歩き出せる。"), symbol: "sunrise.fill")
            ),
            DramaEpisode(
                id: "rain-06", number: 6,
                title: copy("未寄出的清晨", "The Morning Never Sent", "届かなかった朝"),
                sceneCaption: copy("雨停了。電話留下最後一句話，而周岑消失在霧裡。", "The rain ends. The telephone leaves one final sentence as Zhou Cen disappears into the mist.", "雨は止み、電話は最後の言葉を残す。ジョウ・ツェンは霧へ消えた。"),
                clipName: "rain-06-call", durationSeconds: 6, choices: [],
                ending: DramaEnding(title: copy("留在回聲裡", "Left in the Echo", "残響の中に"), summary: copy("她保留了信，也學會不再把未說出口的話交給時間。", "She keeps the letter and learns not to entrust unsaid words to time again.", "彼女は手紙を残し、言えなかった言葉をもう時間に預けないと決める。"), symbol: "phone.down.fill")
            ),
        ]
    )

    static let silentFrequency = preview(
        id: "silent-frequency",
        title: copy("靜默頻率", "Silent Frequency", "沈黙の周波数"),
        subtitle: copy("停播七年的深夜節目，忽然收到來自明天的點歌。", "A radio show silent for seven years receives a request from tomorrow.", "七年前に終わった深夜番組へ、明日からリクエストが届く。"),
        genre: copy("科幻懸疑", "Sci-fi Mystery", "SFミステリー"),
        poster: "rain-stop-phone.png", accent: "59C4BE"
    )

    static let borrowedTomorrow = preview(
        id: "borrowed-tomorrow",
        title: copy("借來的明天", "A Borrowed Tomorrow", "借りた明日"),
        subtitle: copy("她每天醒來，都會少記得一個最重要的人。", "Every morning she forgets one person who matters most.", "目覚めるたび、大切な誰かを一人ずつ忘れていく。"),
        genre: copy("情感奇想", "Emotional Fantasy", "感情ファンタジー"),
        poster: "rain-stop-dawn.png", accent: "8C7AE6"
    )

    private static func preview(id: String, title: LocalizedCopy, subtitle: LocalizedCopy, genre: LocalizedCopy, poster: String, accent: String) -> Drama {
        Drama(id: id, title: title, subtitle: subtitle, synopsis: subtitle, genre: genre, tags: [copy("即將上線", "Coming Soon", "近日公開")], year: 2026, posterImageName: poster, accentHex: accent, availability: .comingSoon, entryEpisodeID: "", episodes: [])
    }

    private static func copy(_ zh: String, _ en: String, _ ja: String) -> LocalizedCopy { .init(zhHant: zh, en: en, ja: ja) }

    private static func choice(_ id: String, _ zhTitle: String, _ zhHint: String, _ enTitle: String, _ enHint: String, _ jaTitle: String, _ jaHint: String, _ destination: String) -> DramaChoice {
        .init(id: id, title: copy(zhTitle, enTitle, jaTitle), consequence: copy(zhHint, enHint, jaHint), destinationEpisodeID: destination)
    }
}
