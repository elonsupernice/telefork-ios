import Foundation

enum StoryLibrary {
    static let stories: [Story] = [midnightTrain, tideSignal, glassGarden]

    static func story(id: String) -> Story? {
        stories.first { $0.id == id }
    }

    private static let midnightTrain = Story(
        id: "midnight-train",
        title: copy("零點列車", "The Zero Train", "零時列車"),
        subtitle: copy("末班車沒有終點站", "The last train has no final stop", "終電には終着駅がない"),
        synopsis: copy(
            "你在午夜登上一列不存在於時刻表的列車。每扇車門後，都藏著一個你曾經錯過的選擇。",
            "At midnight you board a train absent from every timetable. Behind each door waits a choice you once left behind.",
            "深夜、時刻表にない列車へ乗り込む。扉の向こうには、かつて見送った選択が待っている。"
        ),
        genre: copy("時間懸疑", "Time mystery", "時間ミステリー"),
        estimatedMinutes: 7,
        symbol: "tram.fill",
        palette: StoryPalette(startHex: "2F2A78", endHex: "FC6F68", accentHex: "FFD166"),
        entrySceneID: "train-platform",
        scenes: [
            scene(
                "train-platform", 1,
                copy("沒有編號的月台", "The platform without a number", "番号のないホーム"),
                copy(
                    "車站的鐘停在 00:00。廣播沒有聲音，只有一列銀色列車滑進沒有編號的月台。車門打開時，你看見座位上放著一封寫給十年前自己的信。",
                    "The station clock is frozen at 00:00. A silver train glides toward an unnumbered platform. On a seat rests a letter addressed to you ten years ago.",
                    "駅の時計は零時で止まっている。銀色の列車が番号のないホームへ滑り込み、座席には十年前の自分宛ての手紙が置かれていた。"
                ),
                copy("有些列車不是帶你去遠方，而是帶你回到沒有說完的那句話。", "Some trains do not take you far away. They take you back to the sentence you never finished.", "遠くへ運ぶのではなく、言い終えなかった言葉へ戻す列車もある。"),
                [
                    choice("train-open-letter", copy("拆開那封信", "Open the letter", "手紙を開く"), copy("面對過去", "Face the past", "過去と向き合う"), "train-letter"),
                    choice("train-find-conductor", copy("去找列車長", "Find the conductor", "車掌を探す"), copy("先弄清規則", "Learn the rules first", "まず規則を知る"), "train-corridor")
                ]
            ),
            scene(
                "train-letter", 2,
                copy("未寄出的道歉", "The apology never sent", "届かなかった謝罪"),
                copy(
                    "信裡只有一句話：『那天我其實看見你回頭。』紙背浮出兩個站名——舊城與明日。車廂開始分岔，左側窗外是下雨的校門，右側是一座晨光中的陌生城市。",
                    "The letter holds one line: “I saw you turn back that day.” Two station names surface on the paper—Old Town and Tomorrow. The carriage splits between a rainy school gate and an unknown city at dawn.",
                    "手紙には一行だけ。『あの日、君が振り返ったのを見ていた。』紙の裏に“旧市街”と“明日”の二駅が浮かび、車両は雨の校門と朝焼けの街へ分かれる。"
                ), nil,
                [
                    choice("train-old-town", copy("前往舊城", "Go to Old Town", "旧市街へ"), copy("補上那句話", "Finish the sentence", "言葉を伝える"), "train-old-town"),
                    choice("train-tomorrow", copy("選擇明日", "Choose Tomorrow", "明日を選ぶ"), copy("不再回頭", "Do not look back", "振り返らない"), "train-tomorrow")
                ]
            ),
            scene(
                "train-corridor", 2,
                copy("收票的人", "The ticket keeper", "切符を集める人"),
                copy(
                    "走廊盡頭坐著一位戴白手套的老人。他說車票不是用錢買，而是用一段願意放下的記憶交換。你口袋裡出現兩張票：『遺憾』與『名字』。",
                    "At the corridor’s end sits an old man in white gloves. Tickets, he says, cost one memory you are willing to release. Two appear in your pocket: Regret and Name.",
                    "通路の奥に白い手袋の老人がいる。切符の代金は、手放す覚悟のある記憶だという。ポケットには『後悔』と『名前』の二枚が現れた。"
                ), nil,
                [
                    choice("train-give-regret", copy("交出『遺憾』", "Give up Regret", "『後悔』を渡す"), copy("保留那個名字", "Keep the name", "名前を残す"), "train-old-town"),
                    choice("train-give-name", copy("交出『名字』", "Give up the Name", "『名前』を渡す"), copy("保留遺憾", "Keep the regret", "後悔を残す"), "train-nameless")
                ]
            ),
            scene(
                "train-old-town", 3,
                copy("雨停以前", "Before the rain ends", "雨が止む前に"),
                copy(
                    "月台外仍是十年前的雨。那個人站在校門口，沒有責怪，也沒有催促。你只有一分鐘，可以說出一直沒說出口的話，也可以把信放在長椅上離開。",
                    "Outside waits the rain from ten years ago. They stand by the school gate without blame or hurry. You have one minute to speak, or leave the letter on a bench and go.",
                    "外には十年前の雨。あの人は校門に立ち、責めも急かしもしない。残された一分で言葉を伝えるか、手紙をベンチに置いて去るか。"
                ), nil,
                [
                    choice("train-speak", copy("親口說出來", "Say it aloud", "声にする"), copy("接受任何答案", "Accept any answer", "どんな答えも受け入れる"), "train-ending-reconcile"),
                    choice("train-leave-letter", copy("留下信離開", "Leave the letter", "手紙を置いて去る"), copy("讓過去自己完成", "Let the past finish itself", "過去に委ねる"), "train-ending-release")
                ]
            ),
            scene(
                "train-tomorrow", 3,
                copy("晨光站", "Dawn Station", "朝焼け駅"),
                copy(
                    "列車穿過長夜，城市的輪廓逐漸清晰。廣播第一次響起：『下一站，由你命名。』你可以帶著信下車，也可以把它留在座位上。",
                    "The train crosses the long night as a city sharpens into view. The speaker finally wakes: “Name the next station yourself.” You may carry the letter out, or leave it behind.",
                    "長い夜を抜け、街の輪郭が近づく。初めて放送が流れる。『次の駅には、あなたが名前をつけてください。』手紙を持って降りるか、座席に残すか。"
                ), nil,
                [
                    choice("train-carry-letter", copy("帶著信下車", "Take the letter", "手紙を持って降りる"), copy("記得，但繼續走", "Remember and move on", "覚えたまま進む"), "train-ending-release"),
                    choice("train-leave-past", copy("把信留在車上", "Leave it on the train", "列車に残す"), copy("把空白交給未來", "Give the blank page to the future", "余白を未来へ"), "train-ending-new-name")
                ]
            ),
            endingScene(
                "train-nameless", 3,
                copy("無名站", "The Nameless Stop", "名もなき駅"),
                copy("你忘了那個人的名字，也忘了為何難過。列車把你送回清晨的街道，口袋裡只剩一張空白車票。自由有時很輕，也很安靜。", "You forget the name and the reason it hurt. The train returns you to a morning street with one blank ticket. Freedom can be light—and very quiet.", "名前も、痛みの理由も忘れた。朝の通りへ戻ると、ポケットには白紙の切符だけ。自由は軽く、そして静かだった。"),
                copy("你得到了沒有重量的明天。", "You received a weightless tomorrow.", "重さのない明日を手に入れた。"),
                .unresolved
            ),
            endingScene(
                "train-ending-reconcile", 4,
                copy("雨後月台", "Platform After Rain", "雨上がりのホーム"),
                copy("答案並不完美，但那句話終於抵達。當列車再次鳴笛，你發現自己不再需要回到過去。", "The answer is imperfect, but your words finally arrive. When the train whistles again, you no longer need to return.", "答えは完璧ではない。それでも言葉は届いた。汽笛が響く頃、もう過去へ戻る必要はなかった。"),
                copy("有些和解不是重新開始，而是終於可以告別。", "Some reconciliations are not new beginnings. They are permission to say goodbye.", "和解とは、やり直すことではなく、別れを言えることなのかもしれない。"),
                .luminous
            ),
            endingScene(
                "train-ending-release", 4,
                copy("繼續行駛", "Still Moving", "走り続ける"),
                copy("你沒有改寫那一天，只是重新理解了它。列車抵達清晨，你帶著完整的記憶走進新的街道。", "You do not rewrite that day; you understand it anew. At dawn, you step into a new street carrying the whole memory.", "あの日を書き換えず、別の角度から理解した。夜明け、新しい通りへすべての記憶と共に歩き出す。"),
                copy("放下不是遺忘，而是不再被它決定方向。", "Letting go is not forgetting. It is refusing to let the past choose your direction.", "手放すとは忘れることではなく、過去に行き先を決めさせないこと。"),
                .quiet
            ),
            endingScene(
                "train-ending-new-name", 4,
                copy("你命名的車站", "The Station You Named", "あなたが名づけた駅"),
                copy("車門在一座從未見過的城市打開。你替它取名『此刻』，並在第一班晨光裡走下列車。", "The doors open onto a city you have never seen. You name the station Now and step into the first light.", "見たことのない街で扉が開く。駅を『今』と名づけ、最初の朝日へ降り立った。"),
                copy("下一站不在時刻表上，因為它只屬於你。", "The next stop is not on any timetable because it belongs only to you.", "次の駅が時刻表にないのは、あなただけの駅だから。"),
                .luminous
            )
        ]
    )

    private static let tideSignal = Story(
        id: "tide-signal",
        title: copy("潮汐訊號", "Signal in the Tide", "潮の信号"),
        subtitle: copy("燈塔在暴風前收到未來的呼救", "A lighthouse receives tomorrow’s distress call", "灯台に明日からの救難信号が届く"),
        synopsis: copy("孤島燈塔的無線電傳來一段尚未發生的沉船求救。你只有一個夜晚判斷它是真實、陷阱，還是自己的回聲。", "An island lighthouse receives a mayday from a ship that has not yet sunk. You have one night to decide whether it is real, a trap, or your own echo.", "孤島の灯台に、まだ沈んでいない船から救難信号が届く。真実か罠か、自分の残響かを一夜で見極める。"),
        genre: copy("海岸奇想", "Coastal speculative", "海辺幻想"),
        estimatedMinutes: 6,
        symbol: "water.waves.and.arrow.trianglehead.up",
        palette: StoryPalette(startHex: "0B4F6C", endHex: "55D6BE", accentHex: "F7F3EA"),
        entrySceneID: "tide-radio",
        scenes: [
            scene("tide-radio", 1, copy("明天的呼救", "Tomorrow’s mayday", "明日の救難信号"), copy("暴風雨尚在海平線外，老式無線電卻傳來斷續聲音：『北緯二十三度，船名白燕，請在凌晨三點點亮東側副燈。』港口名冊裡，白燕號明早才會出航。", "The storm is still beyond the horizon when the radio crackles: “White Swallow, latitude twenty-three. Light the east lamp at 03:00.” The ship will not depart until morning.", "嵐はまだ水平線の外。それでも無線機が告げる。『白燕号、北緯二十三度。午前三時に東の副灯を。』船は明朝まで出航しないはずだ。"), copy("海有時先記住結果，再等待原因抵達。", "Sometimes the sea remembers the result before the cause arrives.", "海は時に、原因より先に結果を覚えている。"), [
                choice("tide-answer", copy("回覆訊號", "Answer the signal", "信号に応える"), copy("確認對方身份", "Confirm who is calling", "相手を確かめる"), "tide-voice"),
                choice("tide-check-log", copy("檢查航海日誌", "Check the logbook", "航海日誌を調べる"), copy("相信留下的紀錄", "Trust the written record", "記録を信じる"), "tide-log")
            ]),
            scene("tide-voice", 2, copy("熟悉的聲音", "A familiar voice", "聞き覚えのある声"), copy("對方報出你的名字，並說自己是二十年後的燈塔守望員。訊號背景裡有三短三長三短，還有孩童哼唱你母親教過的旋律。", "The caller says your name and claims to be the keeper twenty years from now. Behind the voice: SOS, then a child humming your mother’s melody.", "相手はあなたの名を呼び、二十年後の灯台守だと名乗る。背後にはSOSと、母が教えた旋律を口ずさむ子どもの声。"), nil, [
                choice("tide-trust", copy("相信並準備副燈", "Trust the call", "信じて副灯を準備"), copy("承擔改變未來的風險", "Risk changing the future", "未来を変える危険を負う"), "tide-lamp"),
                choice("tide-cut", copy("切斷無線電", "Cut the radio", "無線を切る"), copy("遵守燈塔規程", "Follow protocol", "規程に従う"), "tide-storm")
            ]),
            scene("tide-log", 2, copy("被撕掉的一頁", "The missing page", "破られた一頁"), copy("二十年前的同一天也記錄過相同訊號，但關鍵一頁被撕走。夾縫裡藏著一張母親的便條：『如果海再次問你，別只聽規則。』", "The same signal was logged twenty years ago, but the crucial page is gone. In the spine lies your mother’s note: “If the sea asks again, do not listen only to rules.”", "二十年前の同じ日にも同じ信号が記録され、肝心の頁だけがない。背表紙には母のメモ。『海がまた尋ねたら、規則だけを聞かないで。』"), nil, [
                choice("tide-follow-note", copy("依照便條點燈", "Follow the note", "メモに従う"), copy("相信母親留下的判斷", "Trust what she left", "母の判断を信じる"), "tide-lamp"),
                choice("tide-report", copy("向港口回報", "Call the harbor", "港へ報告"), copy("讓所有船停航", "Keep every ship ashore", "全船を停泊させる"), "tide-harbor")
            ]),
            scene("tide-lamp", 3, copy("東側副燈", "The east lamp", "東の副灯"), copy("凌晨三點，暴風突然壓上海面。副燈只能照亮礁石或航道其中一側。無線電裡的聲音說：『照向你最害怕失去的地方。』", "At 03:00 the storm folds over the sea. The lamp can illuminate either the reef or the channel. The voice says, “Aim it at what you are most afraid to lose.”", "午前三時、嵐が海を覆う。副灯が照らせるのは岩礁か航路の片方だけ。声が言う。『最も失いたくない場所を照らして。』"), nil, [
                choice("tide-reef", copy("照亮礁石", "Light the reef", "岩礁を照らす"), copy("警告未知船隻", "Warn an unseen ship", "見えない船へ警告"), "tide-ending-keeper"),
                choice("tide-channel", copy("照亮航道", "Light the channel", "航路を照らす"), copy("引導白燕號回港", "Guide White Swallow home", "白燕号を港へ"), "tide-ending-swallows")
            ]),
            scene("tide-storm", 3, copy("熄滅的燈室", "The dark lantern room", "消えた灯室"), copy("無線電沉默後，主燈也突然熄滅。你可以冒險爬上外廊手動重啟，也可以留在室內等待救援。", "The radio dies, and the main light follows. You can climb the outer gallery to restart it by hand, or stay inside and wait for rescue.", "無線が沈黙すると主灯も消えた。外廊へ出て手動で再点灯するか、室内で救助を待つか。"), nil, [
                choice("tide-climb", copy("走上外廊", "Climb outside", "外廊へ出る"), copy("成為別人的訊號", "Become someone else’s signal", "誰かの信号になる"), "tide-ending-keeper"),
                choice("tide-wait", copy("留在燈室", "Stay inside", "灯室に残る"), copy("接受未知結果", "Accept the unknown", "未知を受け入れる"), "tide-ending-silence")
            ]),
            endingScene("tide-harbor", 3, copy("沒有出航的早晨", "The Morning No One Sailed", "誰も出航しない朝"), copy("港口接受警告，所有船留在岸邊。暴風過後，無線電再沒有響起。你永遠不知道自己救了誰，但白燕號平安停在晨霧裡。", "The harbor heeds your warning. After the storm, the radio never speaks again. You never learn whom you saved, but White Swallow rests safely in the morning fog.", "港は警告を受け入れ、全船が岸に残る。嵐の後、無線は二度と鳴らない。誰を救ったかは不明でも、白燕号は朝霧の中で無事だった。"), copy("並非每次拯救都需要被看見。", "Not every rescue needs to be witnessed.", "すべての救いが目撃される必要はない。"), .quiet),
            endingScene("tide-ending-keeper", 4, copy("守望者的回聲", "The Keeper’s Echo", "灯台守の残響"), copy("燈光穿過雨幕，一艘沒有名字的小船避開礁石。二十年後，你在相同的夜裡拿起無線電，終於明白那道聲音來自哪裡。", "The beam cuts the rain and an unnamed boat clears the reef. Twenty years later, on the same night, you lift the radio and finally understand where the voice came from.", "光が雨を裂き、名もない小舟が岩礁を避ける。二十年後、同じ夜に無線機を取り、あの声の出所を理解する。"), copy("你沒有改變循環；你成為了讓它完整的人。", "You did not break the circle. You became the one who completed it.", "輪を壊したのではなく、完成させる人になった。"), .luminous),
            endingScene("tide-ending-swallows", 4, copy("白燕歸港", "White Swallow Returns", "白燕の帰港"), copy("白燕號沿著副燈回到港內。甲板上沒有船員，只有一個裝著二十年前航海日誌缺頁的玻璃瓶。", "White Swallow follows the lamp home. No crew stands aboard—only a bottle containing the missing page from the old logbook.", "白燕号は副灯をたどり帰港する。甲板に乗員はなく、二十年前の日誌の欠頁を入れた瓶だけがあった。"), copy("海把答案送回來，只是從不保證準時。", "The sea returns its answers, but never promises to be on time.", "海は答えを返す。ただし時間どおりとは限らない。"), .unresolved),
            endingScene("tide-ending-silence", 4, copy("靜默海面", "The Silent Sea", "静かな海"), copy("救援在天亮後抵達。海面平靜得像什麼都沒發生，只有無線電留下最後一段錄音：你自己的呼吸聲。", "Rescue arrives after dawn. The sea is calm as if nothing happened. The radio keeps one final recording: the sound of your own breath.", "夜明け後に救助が来る。海は何もなかったように静かで、無線機には自分の呼吸だけが残っていた。"), copy("沉默也可能是一種選擇，只是它不回答任何人。", "Silence is also a choice, but it answers no one.", "沈黙も選択だ。ただし誰にも答えない。"), .unresolved)
        ]
    )

    private static let glassGarden = Story(
        id: "glass-garden",
        title: copy("玻璃花園", "The Glass Garden", "硝子の庭"),
        subtitle: copy("每朵花都保存一段被刪除的記憶", "Every flower stores an erased memory", "花は消された記憶を宿す"),
        synopsis: copy("城市把痛苦記憶封進玻璃花，並稱之為療癒。身為最後一位園丁，你發現有一朵花正在呼喚自己的名字。", "The city seals painful memories inside glass flowers and calls it healing. As the last gardener, you hear one flower whisper your name.", "街は痛い記憶を硝子の花に封じ、癒やしと呼ぶ。最後の庭師であるあなたを、一輪の花が名前で呼ぶ。"),
        genre: copy("記憶寓言", "Memory fable", "記憶寓話"),
        estimatedMinutes: 8,
        symbol: "camera.macro",
        palette: StoryPalette(startHex: "633C73", endHex: "F29E8E", accentHex: "55D6BE"),
        entrySceneID: "garden-bloom",
        scenes: [
            scene("garden-bloom", 1, copy("夜裡開花", "Blooming at night", "夜に咲く"), copy("玻璃花園只在沒有月亮的夜晚發光。今晚，一朵從未登記的紫色花苞裂開，裡面傳出你的聲音：『別讓他們把我忘掉。』", "The Glass Garden glows only on moonless nights. Tonight an unregistered violet bud opens, carrying your own voice: “Do not let them forget me.”", "硝子の庭は月のない夜だけ光る。今夜、未登録の紫の蕾が開き、自分の声が響く。『私を忘れさせないで。』"), copy("被移走的記憶不會消失，只會在別的地方長出根。", "A removed memory does not vanish. It grows roots somewhere else.", "取り除かれた記憶は消えず、別の場所で根を張る。"), [
                choice("garden-touch", copy("觸碰花瓣", "Touch the petals", "花びらに触れる"), copy("進入保存的記憶", "Enter the stored memory", "保存された記憶へ"), "garden-memory"),
                choice("garden-scan", copy("掃描花朵編號", "Scan its registry", "登録番号を調べる"), copy("查明誰送來它", "Find who brought it", "持ち主を探す"), "garden-archive")
            ]),
            scene("garden-memory", 2, copy("缺席的生日", "The missing birthday", "消えた誕生日"), copy("你站在一間舊公寓裡，桌上有兩個人的生日蛋糕。記憶裡的你正準備按下城市的『刪除悲傷』按鈕，而另一個人請你保留這一天。", "You stand in an old apartment before a cake for two. Your past self is about to press the city’s Delete Sorrow button while someone asks you to keep this day.", "古い部屋、二人分の誕生日ケーキ。過去のあなたは街の『悲しみを削除』ボタンを押そうとし、もう一人はこの日を残してと頼んでいる。"), nil, [
                choice("garden-stop-self", copy("阻止過去的自己", "Stop your past self", "過去の自分を止める"), copy("承受完整記憶", "Keep the whole memory", "記憶を丸ごと受け取る"), "garden-crack"),
                choice("garden-watch", copy("讓記憶繼續", "Let it continue", "記憶を見届ける"), copy("先理解當時的決定", "Understand the decision", "決断を理解する"), "garden-name")
            ]),
            scene("garden-archive", 2, copy("不存在的檔案", "The file that does not exist", "存在しない記録"), copy("系統顯示花朵的捐贈者是你，但日期在三年後。附註只有一句：『當花園開始說話，選擇一朵讓它枯萎。』", "The registry names you as donor—three years from now. One note remains: “When the garden begins to speak, choose one flower to let wither.”", "登録上の提供者は三年後のあなた。備考には一文。『庭が話し始めたら、一輪だけ枯らして。』"), nil, [
                choice("garden-delete-violet", copy("讓紫花枯萎", "Let the violet wither", "紫の花を枯らす"), copy("相信未來的警告", "Trust the future warning", "未来の警告を信じる"), "garden-ending-silent"),
                choice("garden-open-vault", copy("打開記憶庫", "Open the memory vault", "記憶庫を開く"), copy("找出所有被藏起來的事", "Reveal what was hidden", "隠されたものを見る"), "garden-vault")
            ]),
            scene("garden-crack", 3, copy("第一道裂痕", "The first crack", "最初のひび"), copy("你抓住過去的手，玻璃花園同時出現裂痕。所有被刪除的悲傷開始回到城市。你可以關閉花園，或把自己的記憶當作緩衝。", "You catch your past hand, and cracks race across the garden. Every deleted sorrow begins returning to the city. You can shut the garden down or offer your memory as a buffer.", "過去の手をつかむと庭全体にひびが走り、消された悲しみが街へ戻り始める。庭を閉じるか、自分の記憶を緩衝材にするか。"), nil, [
                choice("garden-close", copy("關閉整座花園", "Close the garden", "庭を閉じる"), copy("讓記憶回到主人身上", "Return memories to their owners", "記憶を持ち主へ返す"), "garden-ending-return"),
                choice("garden-absorb", copy("吸收花園的裂痕", "Absorb the fracture", "ひびを引き受ける"), copy("成為新的守護者", "Become its new guardian", "新しい守護者になる"), "garden-ending-keeper")
            ]),
            scene("garden-name", 3, copy("被刪除的名字", "The erased name", "消された名前"), copy("你終於記起蛋糕旁的人叫洛安。那天不是他離開你，而是你們共同決定刪除一場無法挽回的事故。花朵問：『要把名字還給城市嗎？』", "You remember the other person: Rowan. They did not leave; together you erased an irreversible accident. The flower asks, “Shall I return the name to the city?”", "ケーキの隣にいた人はローワン。去ったのではなく、取り返せない事故を二人で消したのだ。花が問う。『名前を街へ返しますか。』"), nil, [
                choice("garden-return-name", copy("把名字還回去", "Return the name", "名前を返す"), copy("讓所有人重新記得", "Let everyone remember", "皆に思い出させる"), "garden-ending-return"),
                choice("garden-keep-private", copy("只由自己記住", "Keep it to yourself", "自分だけで覚える"), copy("保護城市，也保留真相", "Protect the city and the truth", "街と真実を守る"), "garden-ending-keeper")
            ]),
            scene("garden-vault", 3, copy("萬朵花的聲音", "Ten thousand voices", "一万の花の声"), copy("記憶庫打開後，整座花園同時呼吸。你可以釋放全部記憶，也可以只取回那朵紫花，再次封鎖入口。", "The vault opens and the whole garden breathes. You may release every memory, or recover only the violet flower and seal the door again.", "記憶庫が開き、庭全体が呼吸する。すべてを解放するか、紫の花だけを取り戻して再び封じるか。"), nil, [
                choice("garden-release-all", copy("釋放所有記憶", "Release them all", "すべて解放する"), copy("結束城市的遺忘", "End the city’s forgetting", "街の忘却を終わらせる"), "garden-ending-return"),
                choice("garden-seal", copy("帶走紫花並封鎖", "Take the violet and seal the vault", "紫の花を持ち封じる"), copy("成為唯一知道真相的人", "Keep the only truth", "唯一の真実を守る"), "garden-ending-keeper")
            ]),
            endingScene("garden-ending-silent", 3, copy("安靜的花園", "The Quiet Garden", "静かな庭"), copy("紫花化成透明碎片，花園重新安靜。你保住了城市的平穩，也失去最後一次知道自己為何悲傷的機會。", "The violet becomes clear shards and the garden falls quiet. You preserve the city’s calm and lose your last chance to learn why you were sad.", "紫の花は透明な欠片になり、庭は静まる。街の平穏を守る代わりに、自分の悲しみを知る最後の機会を失った。"), copy("沒有痛苦的平靜，仍然會留下空缺。", "Peace without pain can still leave an absence.", "痛みのない平穏にも、空白は残る。"), .unresolved),
            endingScene("garden-ending-return", 4, copy("記憶回城", "Memories Return", "記憶が街へ帰る"), copy("清晨，玻璃花一朵接一朵融化。城市第一次同時哭泣，也第一次真正開始療癒。", "At dawn, the glass flowers melt one by one. For the first time the city grieves together—and begins to heal for real.", "夜明け、硝子の花が一輪ずつ溶ける。街は初めて共に泣き、初めて本当に癒やされ始める。"), copy("療癒不是刪除，而是讓記憶找到可以安放的位置。", "Healing is not deletion. It is giving memory somewhere it can rest.", "癒やしは削除ではなく、記憶に居場所を与えること。"), .luminous),
            endingScene("garden-ending-keeper", 4, copy("最後的園丁", "The Last Gardener", "最後の庭師"), copy("你保留真相，讓其他記憶繼續沉睡。花園不再屬於城市，而成為一座等待人們準備好後再開門的圖書館。", "You keep the truth while other memories sleep. The garden stops being the city’s machine and becomes a library waiting for people to be ready.", "真実を抱き、ほかの記憶を眠らせる。庭は街の装置ではなく、人々の準備が整うまで待つ図書館になった。"), copy("守護不是替別人選擇，而是替他們保留選擇的可能。", "To guard is not to choose for others, but to preserve their chance to choose.", "守るとは代わりに選ぶことではなく、選べる可能性を残すこと。"), .quiet)
        ]
    )

    private static func copy(_ zhHant: String, _ en: String, _ ja: String) -> LocalizedCopy {
        LocalizedCopy(zhHant: zhHant, en: en, ja: ja)
    }

    private static func scene(
        _ id: String,
        _ chapter: Int,
        _ heading: LocalizedCopy,
        _ body: LocalizedCopy,
        _ quote: LocalizedCopy?,
        _ choices: [StoryChoice]
    ) -> StoryScene {
        StoryScene(id: id, chapter: chapter, heading: heading, body: body, quote: quote, choices: choices, ending: nil)
    }

    private static func choice(
        _ id: String,
        _ title: LocalizedCopy,
        _ hint: LocalizedCopy,
        _ destination: String
    ) -> StoryChoice {
        StoryChoice(id: id, title: title, hint: hint, destinationSceneID: destination)
    }

    private static func endingScene(
        _ id: String,
        _ chapter: Int,
        _ heading: LocalizedCopy,
        _ body: LocalizedCopy,
        _ summary: LocalizedCopy,
        _ tone: EndingTone
    ) -> StoryScene {
        StoryScene(
            id: id,
            chapter: chapter,
            heading: heading,
            body: body,
            quote: summary,
            choices: [],
            ending: StoryEnding(title: heading, summary: summary, tone: tone)
        )
    }
}

